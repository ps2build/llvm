//===- MipsR5900FPUAcc.cpp - R5900 FPU accumulator chains -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Turns a sum of products
//
//   t0 = a*b; t1 = c*d; t2 = e*f; s = (t0 + t1) + t2
//
// into the accumulator sequence of the R5900 FPU
//
//   mula.s a, b; madda.s c, d; madd.s s, e, f
//
// which is shorter, and whose steps need no register for the products. Each
// step rounds like the multiply and the add that it replaces, so the result
// does not change and no fast-math flag is needed. The adds must form a chain
// (each add reads the previous one) and each product and add must have no
// other reader. ACC is an unallocatable register, so the scheduler keeps the
// instructions of one chain apart from those of another.
//
//===----------------------------------------------------------------------===//

#include "Mips.h"
#include "MipsInstrInfo.h"
#include "MipsSubtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#define DEBUG_TYPE "mips-r5900-fpu-acc"

using namespace llvm;

STATISTIC(NumChains, "Number of FPU accumulator chains formed");

namespace {

class MipsR5900FPUAcc : public MachineFunctionPass {
public:
  static char ID;
  MipsR5900FPUAcc() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override { return "R5900 FPU accumulator chains"; }
  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  MachineRegisterInfo *MRI = nullptr;
  const MipsInstrInfo *TII = nullptr;

  /// The multiply in \p MBB that defines \p Reg and that only the sum reads.
  MachineInstr *getProduct(Register Reg, const MachineBasicBlock &MBB) const {
    if (!Reg.isVirtual() || !MRI->hasOneNonDBGUse(Reg))
      return nullptr;
    MachineInstr *Def = MRI->getVRegDef(Reg);
    return Def && Def->getParent() == &MBB && Def->getOpcode() == Mips::FMUL_S
               ? Def
               : nullptr;
  }
  MachineInstr *getAdd(Register Reg, const MachineBasicBlock &MBB) const {
    if (!Reg.isVirtual() || !MRI->hasOneNonDBGUse(Reg))
      return nullptr;
    MachineInstr *Def = MRI->getVRegDef(Reg);
    return Def && Def->getParent() == &MBB && Def->getOpcode() == Mips::FADD_S
               ? Def
               : nullptr;
  }
  bool tryRoot(MachineInstr &Root, SmallPtrSetImpl<MachineInstr *> &Gone);
};

} // namespace

char MipsR5900FPUAcc::ID = 0;
INITIALIZE_PASS(MipsR5900FPUAcc, DEBUG_TYPE, "R5900 FPU accumulator chains",
                false, false)

bool MipsR5900FPUAcc::tryRoot(MachineInstr &Root,
                              SmallPtrSetImpl<MachineInstr *> &Gone) {
  MachineBasicBlock &MBB = *Root.getParent();
  SmallVector<MachineInstr *, 8> Adds;     // Root first.
  SmallVector<MachineInstr *, 8> Products; // In the order of evaluation.

  // Walk down the chain of adds: the innermost add has two products, every
  // other add has one product and the previous add.
  MachineInstr *Cur = &Root;
  SmallVector<MachineInstr *, 8> Late; // Products of outer adds, outermost first.
  while (true) {
    Adds.push_back(Cur);
    Register A = Cur->getOperand(1).getReg(), B = Cur->getOperand(2).getReg();
    MachineInstr *PA = getProduct(A, MBB), *PB = getProduct(B, MBB);
    if (PA && PB) {
      Products.push_back(PA);
      Products.push_back(PB);
      break;
    }
    MachineInstr *Next = nullptr;
    MachineInstr *P = nullptr;
    if (PB && (Next = getAdd(A, MBB)))
      P = PB;
    else if (PA && (Next = getAdd(B, MBB)))
      P = PA;
    else
      return false;
    Late.push_back(P);
    Cur = Next;
  }
  for (MachineInstr *P : reverse(Late))
    Products.push_back(P);
  if (Products.size() < 2)
    return false;

  LLVM_DEBUG(dbgs() << "R5900 FPU ACC: chain of " << Products.size()
                    << " products\n");
  DebugLoc DL = Root.getDebugLoc();
  auto Ops = [&](MachineInstrBuilder MIB, MachineInstr *P) {
    MIB.addReg(P->getOperand(1).getReg()).addReg(P->getOperand(2).getReg());
  };
  Ops(BuildMI(MBB, Root, DL, TII->get(Mips::MULA_S_R5900)), Products[0]);
  for (unsigned I = 1, E = Products.size() - 1; I != E; ++I)
    Ops(BuildMI(MBB, Root, DL, TII->get(Mips::MADDA_S_R5900)), Products[I]);
  Ops(BuildMI(MBB, Root, DL, TII->get(Mips::MADD_S_R5900),
              Root.getOperand(0).getReg()),
      Products.back());

  for (MachineInstr *P : Products)
    P->eraseFromParent();
  for (MachineInstr *A : Adds) {
    Gone.insert(A);
    A->eraseFromParent();
  }
  ++NumChains;
  return true;
}

bool MipsR5900FPUAcc::runOnMachineFunction(MachineFunction &MF) {
  const auto &STI = MF.getSubtarget<MipsSubtarget>();
  if (!STI.isR5900() || STI.useSoftFloat())
    return false;
  MRI = &MF.getRegInfo();
  TII = STI.getInstrInfo();

  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    // The last add of a chain first, so that the longest chain is taken.
    SmallVector<MachineInstr *, 16> Roots;
    for (MachineInstr &MI : reverse(MBB))
      if (MI.getOpcode() == Mips::FADD_S)
        Roots.push_back(&MI);
    SmallPtrSet<MachineInstr *, 16> Gone;
    for (MachineInstr *Root : Roots) {
      if (Gone.count(Root))
        continue;
      if (tryRoot(*Root, Gone))
        Changed = true;
    }
  }
  return Changed;
}

FunctionPass *llvm::createMipsR5900FPUAccPass() {
  return new MipsR5900FPUAcc();
}
