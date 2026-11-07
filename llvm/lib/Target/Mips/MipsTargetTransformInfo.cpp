//===-- MipsTargetTransformInfo.cpp - Mips specific TTI ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MipsTargetTransformInfo.h"

using namespace llvm;

// MMI works on the 128-bit core registers, which the integer code shares, so
// the vectorizer gets one vector register width and no interleaving.
TypeSize MipsTTIImpl::getRegisterBitWidth(TTI::RegisterKind K) const {
  if (K == TTI::RGK_FixedWidthVector && ST->isR5900() && !ST->hasMSA())
    return TypeSize::getFixed(128);
  return BaseT::getRegisterBitWidth(K);
}

unsigned MipsTTIImpl::getNumberOfRegisters(unsigned ClassID) const {
  // The R5900 has 32 general registers; MMI vectors live in the same file.
  // The base default of 8 makes the vectorizer cap interleaving too early.
  if (ST->isR5900() && !ST->hasMSA())
    return 32;
  return BaseT::getNumberOfRegisters(ClassID);
}

unsigned MipsTTIImpl::getMaxInterleaveFactor(ElementCount VF,
                                            bool HasUnorderedReductions) const {
  // The in-order core stalls on the ldl/ldr -> pcpyld and pmaxh dependency
  // chains; four independent vectors per iteration hide that latency.
  if (ST->isR5900() && !ST->hasMSA())
    return 4;
  return BaseT::getMaxInterleaveFactor(VF, HasUnorderedReductions);
}

// With 32-element main iterations, the scalar remainder of an i16 loop runs up
// to 31 iterations; an 8-wide vector epilogue removes most of them.
bool MipsTTIImpl::preferEpilogueVectorization(ElementCount Iters) const {
  if (ST->isR5900() && !ST->hasMSA())
    return true;
  return BaseT::preferEpilogueVectorization(Iters);
}

// A 16-byte aligned 128-bit vector is one lq/sq; an unaligned one is an
// ldl/ldr pair per half joined (or an sdl/sdr pair split) by pcpyld/pcpyud,
// about 5 cycles to the use for a load and 4 for a store. A 32-bit-element
// access aligned to its element is costed as aligned because MipsMMIAlign
// versions the vector loop on a run-time check.
InstructionCost MipsTTIImpl::getMemoryOpCost(
    unsigned Opcode, Type *Src, Align Alignment, unsigned AddressSpace,
    TTI::TargetCostKind CostKind, TTI::OperandValueInfo OpInfo,
    const Instruction *I) const {
  auto *VTy = dyn_cast<FixedVectorType>(Src);
  if (ST->isR5900() && !ST->hasMSA() && VTy &&
      VTy->getPrimitiveSizeInBits().getFixedValue() == 128 &&
      (Opcode == Instruction::Load || Opcode == Instruction::Store))
    return Alignment >= Align(16) ||
                   (VTy->getScalarSizeInBits() == 32 && Alignment >= Align(4))
               ? 1
               : (Opcode == Instruction::Load ? 5 : 4);
  return BaseT::getMemoryOpCost(Opcode, Src, Alignment, AddressSpace, CostKind,
                                OpInfo, I);
}

bool MipsTTIImpl::hasDivRemOp(Type *DataType, bool IsSigned) const {
  EVT VT = TLI->getValueType(DL, DataType);
  return TLI->isOperationLegalOrCustom(IsSigned ? ISD::SDIVREM : ISD::UDIVREM,
                                       VT);
}

void MipsTTIImpl::getUnrollingPreferences(
    Loop *L, ScalarEvolution &SE, TTI::UnrollingPreferences &UP,
    OptimizationRemarkEmitter *ORE) const {
  BaseT::getUnrollingPreferences(L, SE, UP, ORE);
  if (!ST->isR5900() || L->getNumBlocks() != 1)
    return;
  // Rig timings: loops with a load of 4 bytes or more gain from unrolling;
  // byte loops are short and store-only loops lose to the scheduler.
  const DataLayout &DL = L->getHeader()->getDataLayout();
  // A narrow load feeding another load (a table lookup) is a latency chain
  // that unrolling overlaps, so only lone narrow loads are left alone.
  unsigned NumLoads = 0;
  bool HasNarrow = false;
  for (const Instruction &I : *L->getHeader())
    if (const auto *LI = dyn_cast<LoadInst>(&I)) {
      ++NumLoads;
      if (DL.getTypeStoreSize(LI->getType()) < 4)
        HasNarrow = true;
    }
  if (NumLoads == 0 || (HasNarrow && NumLoads < 2))
    return;
  UP.Partial = true;
  UP.Runtime = true;
  UP.PartialThreshold = 120;
}

bool MipsTTIImpl::shouldMaximizeVectorBandwidth(
    TargetTransformInfo::RegisterKind K) const {
  // Size the vector from the narrowest element of the loop, not the widest:
  // MMI widens a byte or halfword register into several by interleaving, and
  // packs several into one.
  return ST->isR5900() && !ST->hasMSA() &&
         K == TargetTransformInfo::RGK_FixedWidthVector;
}

InstructionCost MipsTTIImpl::getCastInstrCost(unsigned Opcode, Type *Dst,
                                              Type *Src,
                                              TTI::CastContextHint CCH,
                                              TTI::TargetCostKind CostKind,
                                              const Instruction *I) const {
  // MMI widens and narrows integer vectors by interleaving with zero or
  // itself (PEXT*, plus a shift to sign extend) and by packing (PPAC*): about
  // one instruction per 128-bit register of the wider type and step.
  auto *DstTy = dyn_cast<FixedVectorType>(Dst);
  auto *SrcTy = dyn_cast<FixedVectorType>(Src);
  if (ST->isR5900() && !ST->hasMSA() && DstTy && SrcTy &&
      DstTy->getElementType()->isIntegerTy() &&
      SrcTy->getElementType()->isIntegerTy() &&
      (Opcode == Instruction::ZExt || Opcode == Instruction::SExt ||
       Opcode == Instruction::Trunc)) {
    unsigned DstBits = DstTy->getScalarSizeInBits();
    unsigned SrcBits = SrcTy->getScalarSizeInBits();
    unsigned Wide = std::max(DstBits, SrcBits);
    unsigned Narrow = std::min(DstBits, SrcBits);
    if (Wide <= 32 && Narrow >= 8 && DstBits != SrcBits) {
      unsigned WideRegs = std::max<unsigned>(
          1, (DstTy->getNumElements() * Wide + 127) / 128);
      unsigned Steps = Log2_32(Wide / Narrow);
      return WideRegs * Steps * (Opcode == Instruction::SExt ? 2 : 1);
    }
  }
  return BaseT::getCastInstrCost(Opcode, Dst, Src, CCH, CostKind, I);
}

InstructionCost MipsTTIImpl::getArithmeticInstrCost(
    unsigned Opcode, Type *Ty, TTI::TargetCostKind CostKind,
    TTI::OperandValueInfo Op1Info, TTI::OperandValueInfo Op2Info,
    ArrayRef<const Value *> Args, const Instruction *CxtI) const {
  // R5900 FPU arithmetic has a 4-cycle latency, and the FPU has no conditional
  // move, so speculating it to form a select also costs a compare and branch.
  if (ST->isR5900() && Ty->isFloatTy() &&
      (CostKind == TTI::TCK_Latency || CostKind == TTI::TCK_SizeAndLatency)) {
    switch (Opcode) {
    case Instruction::FAdd:
    case Instruction::FSub:
    case Instruction::FMul:
    case Instruction::FNeg:
      return 4;
    default:
      break;
    }
  }
  // MMI has no multiply, divide, 64-bit add/sub or variable-amount shift of a
  // 128-bit vector: each element goes through a scalar operation on a stack
  // temporary. The overhead per element is set from rig timings of raster.
  if (auto *VTy = dyn_cast<FixedVectorType>(Ty);
      ST->isR5900() && !ST->hasMSA() && VTy &&
      VTy->getElementType()->isIntegerTy() &&
      VTy->getPrimitiveSizeInBits().getFixedValue() % 128 == 0) {
    unsigned EltBits = VTy->getScalarSizeInBits();
    // A widening 16x16->32 multiply of 8 lanes is one PMULTH, two moves out of
    // HI/LO and the repacking of the halves.
    if (Opcode == Instruction::Mul && VTy->getNumElements() == 8 &&
        EltBits == 32 && Args.size() == 2 &&
        all_of(Args, [](const Value *A) {
          auto *Ext = dyn_cast<SExtInst>(A);
          return Ext && Ext->getSrcTy()->getScalarSizeInBits() == 16;
        }))
      return 5;
    bool InMMI;
    switch (Opcode) {
    case Instruction::Add:
    case Instruction::Sub:
      InMMI = EltBits <= 32;
      break;
    case Instruction::And:
    case Instruction::Or:
    case Instruction::Xor:
      InMMI = true;
      break;
    case Instruction::Shl:
    case Instruction::LShr:
    case Instruction::AShr:
      InMMI = (EltBits == 16 || EltBits == 32) && Op2Info.isUniform() &&
              Op2Info.isConstant();
      break;
    default:
      InMMI = false;
      break;
    }
    if (!InMMI) {
      InstructionCost ScalarCost = getArithmeticInstrCost(
          Opcode, VTy->getElementType(), CostKind, Op1Info.getNoProps(),
          Op2Info.getNoProps());
      return VTy->getNumElements() * (ScalarCost + 8);
    }
  }
  return BaseT::getArithmeticInstrCost(Opcode, Ty, CostKind, Op1Info, Op2Info,
                                       Args, CxtI);
}

// A widening multiply is selected as PMULTH only when instruction selection
// sees the extensions of its operands, so bring a hoisted sext back next to
// the multiply rather than keeping a v8i32 copy live across the loop.
bool MipsTTIImpl::isProfitableToSinkOperands(
    Instruction *I, SmallVectorImpl<Use *> &Ops) const {
  auto *VTy = dyn_cast<FixedVectorType>(I->getType());
  if (!ST->isR5900() || ST->hasMSA() || I->getOpcode() != Instruction::Mul ||
      !VTy || VTy->getNumElements() != 8 || VTy->getScalarSizeInBits() != 32)
    return false;
  for (Use &U : I->operands()) {
    auto *Ext = dyn_cast<SExtInst>(U.get());
    if (!Ext || Ext->getSrcTy()->getScalarSizeInBits() != 16)
      return false;
  }
  for (Use &U : I->operands())
    Ops.push_back(&U);
  return true;
}

bool MipsTTIImpl::isLSRCostLess(const TargetTransformInfo::LSRCost &C1,
                                const TargetTransformInfo::LSRCost &C2) const {
  // MIPS specific here are "instruction number 1st priority".
  // If we need to emit adds inside the loop to add up base registers, then
  // we need at least one extra temporary register.
  unsigned C1NumRegs = C1.NumRegs + (C1.NumBaseAdds != 0);
  unsigned C2NumRegs = C2.NumRegs + (C2.NumBaseAdds != 0);
  return std::tie(C1.Insns, C1NumRegs, C1.AddRecCost, C1.NumIVMuls,
                  C1.NumBaseAdds, C1.ScaleCost, C1.ImmCost, C1.SetupCost) <
         std::tie(C2.Insns, C2NumRegs, C2.AddRecCost, C2.NumIVMuls,
                  C2.NumBaseAdds, C2.ScaleCost, C2.ImmCost, C2.SetupCost);
}

// The IOP has very little RAM, so under -Os inlining must not grow code: bring
// the -Os threshold (50) down to the -Oz one (5). The unsigned wraparound is
// added to the int threshold by the inliner.
unsigned MipsTTIImpl::adjustInliningThreshold(const CallBase *CB) const {
  if (ST->isR3000A() && CB->getCaller()->hasOptSize())
    return static_cast<unsigned>(-45);
  return 0;
}
