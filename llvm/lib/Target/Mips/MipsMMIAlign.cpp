//===-- MipsMMIAlign.cpp - Align vectorized loops for MMI lq/sq -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MipsMMIAlign.h"
#include "MipsSubtarget.h"
#include "MipsTargetMachine.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/PatternMatch.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/Transforms/Utils/LoopUtils.h"
#include "llvm/Transforms/Utils/ScalarEvolutionExpander.h"

using namespace llvm;

#define DEBUG_TYPE "mips-mmi-align"

static cl::opt<bool> DisableMMIAlign("mips-mmi-align-disable", cl::Hidden,
                                     cl::init(false));

namespace {

// A load or store of a whole number of 16-byte vectors with less alignment
// than 16.
bool isUnderalignedWideAccess(Instruction &I, const DataLayout &DL,
                              Value *&Ptr, Type *&Ty) {
  Align A;
  if (auto *LI = dyn_cast<LoadInst>(&I)) {
    Ptr = LI->getPointerOperand();
    Ty = LI->getType();
    A = LI->getAlign();
    if (!LI->isSimple())
      return false;
  } else if (auto *SI = dyn_cast<StoreInst>(&I)) {
    Ptr = SI->getPointerOperand();
    Ty = SI->getValueOperand()->getType();
    A = SI->getAlign();
    if (!SI->isSimple())
      return false;
  } else {
    return false;
  }
  if (!Ty->isVectorTy() || A >= Align(16))
    return false;
  TypeSize Size = DL.getTypeStoreSize(Ty);
  return !Size.isScalable() && Size.getFixedValue() % 16 == 0;
}

bool alignLoop(Loop &L, ScalarEvolution &SE, DominatorTree &DT, LoopInfo &LI,
               const DataLayout &DL) {
  if (!L.isInnermost() || L.getNumBlocks() != 1 ||
      !getBooleanLoopAttribute(&L, "llvm.loop.isvectorized"))
    return false;

  BasicBlock *Ph = L.getLoopPreheader();
  if (!Ph || !Ph->getSinglePredecessor())
    return false;
  BasicBlock *Pred = Ph->getSinglePredecessor();
  auto *Br = dyn_cast<CondBrInst>(Pred->getTerminator());
  if (!Br)
    return false;
  BasicBlock *Scalar = Br->getSuccessor(0) == Ph ? Br->getSuccessor(1)
                                                  : Br->getSuccessor(0);
  if (Scalar == Ph || Scalar == Pred || L.contains(Scalar))
    return false;

  SCEVExpander Exp(SE, "mmi.align");

  // Accesses whose address is start + k * 16 per iteration, so one check of
  // the start covers every iteration.
  SmallVector<Instruction *, 8> Accesses;
  SmallVector<const SCEV *, 4> Starts;
  for (Instruction &I : *L.getHeader()) {
    Value *Ptr;
    Type *Ty;
    if (!isUnderalignedWideAccess(I, DL, Ptr, Ty))
      continue;
    auto *AR = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(Ptr));
    if (!AR || !AR->isAffine() || AR->getLoop() != &L)
      continue;
    auto *Step = dyn_cast<SCEVConstant>(AR->getStepRecurrence(SE));
    if (!Step || Step->getAPInt().urem(16) != 0)
      continue;
    const SCEV *Start = AR->getStart();
    if (!Exp.isSafeToExpandAt(Start, Ph->getTerminator()))
      continue;
    // A start a constant, non-multiple-of-16 offset from its base, as in
    // a[1], is not aligned when the base is: leave it to ldl/ldr.
    if (auto *Off = dyn_cast<SCEVConstant>(
            SE.getMinusSCEV(Start, SE.getPointerBase(Start))))
      if (Off->getAPInt().urem(16) != 0)
        continue;
    Accesses.push_back(&I);
    if (!is_contained(Starts, Start))
      Starts.push_back(Start);
  }
  if (Accesses.empty())
    return false;

  // Two starts a constant, non-multiple-of-16 distance apart (a[i] and
  // a[i + 1]) can never both be aligned, so the vector loop is never entered.
  bool NeverAligned = false;
  for (const SCEV *S : drop_begin(Starts))
    if (auto *Diff =
            dyn_cast<SCEVConstant>(SE.getMinusSCEV(S, Starts.front())))
      NeverAligned |= Diff->getAPInt().urem(16) != 0;

  BasicBlock *Check = SplitEdge(Pred, Ph, &DT, &LI);
  Check->setName("mmi.align.check");
  Instruction *OldTerm = Check->getTerminator();

  IRBuilder<> B(OldTerm);
  Type *IntPtrTy = DL.getIntPtrType(Check->getContext());
  Value *Bits = nullptr;
  for (const SCEV *S : Starts) {
    Value *P = Exp.expandCodeFor(S, nullptr, OldTerm->getIterator());
    Value *V = B.CreatePtrToInt(P, IntPtrTy);
    Bits = Bits ? B.CreateOr(Bits, V) : V;
  }
  Value *Low = B.CreateAnd(Bits, ConstantInt::get(IntPtrTy, 15));
  Value *Misaligned = B.CreateICmpNE(Low, ConstantInt::get(IntPtrTy, 0));
  B.CreateCondBr(NeverAligned ? B.getTrue() : Misaligned, Scalar, Ph);
  OldTerm->eraseFromParent();

  for (PHINode &Phi : Scalar->phis())
    Phi.addIncoming(Phi.getIncomingValueForBlock(Pred), Check);
  DT.insertEdge(Check, Scalar);

  for (Instruction *I : Accesses) {
    if (auto *LdI = dyn_cast<LoadInst>(I))
      LdI->setAlignment(Align(16));
    else
      cast<StoreInst>(I)->setAlignment(Align(16));
  }
  return true;
}

} // namespace

PreservedAnalyses MipsMMIAlignPass::run(Function &F,
                                        FunctionAnalysisManager &AM) {
  const MipsSubtarget &ST = *TM.getSubtargetImpl(F);
  if (DisableMMIAlign || !ST.isR5900() || ST.hasMSA())
    return PreservedAnalyses::all();
  auto &LI = AM.getResult<LoopAnalysis>(F);
  auto &SE = AM.getResult<ScalarEvolutionAnalysis>(F);
  auto &DT = AM.getResult<DominatorTreeAnalysis>(F);
  const DataLayout &DL = F.getDataLayout();

  SmallVector<Loop *, 8> Loops;
  for (Loop *Top : LI)
    for (Loop *L : depth_first(Top))
      Loops.push_back(L);

  bool Changed = false;
  for (Loop *L : Loops)
    Changed |= alignLoop(*L, SE, DT, LI, DL);
  if (!Changed)
    return PreservedAnalyses::all();
  PreservedAnalyses PA;
  PA.preserve<DominatorTreeAnalysis>();
  PA.preserve<LoopAnalysis>();
  return PA;
}
