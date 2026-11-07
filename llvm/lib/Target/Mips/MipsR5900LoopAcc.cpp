//===- MipsR5900LoopAcc.cpp - R5900 FPU accumulator in loops -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A reduction loop such as a dot product, after the loop has been unrolled
// into several partial sums,
//
//   s0 = phi(i0, s0'); s1 = phi(i1, s1'); ...
//   s0' = s0 + a0*b0; s1' = s1 + a1*b1; ...
//
// keeps the sum in the FPU accumulator instead: one madda.s per product, with
// no add.s and no partial sums in registers.
//
//   preheader:  adda.s start, 0.0
//   loop:       madda.s a0, b0; madda.s a1, b1; ...
//   exit:       msub.s r, 0.0, 0.0       (r = ACC - 0.0*0.0)
//
// The adds must be allowed to reassociate and to ignore the sign of a zero.
// All initial values but one must be +0.0. The loop must be a single block
// with one preheader and one exit block that only the loop enters, and must
// not touch ACC otherwise.
//
//===----------------------------------------------------------------------===//

#include "Mips.h"
#include "MipsInstrInfo.h"
#include "MipsSubtarget.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#define DEBUG_TYPE "mips-r5900-loop-acc"

using namespace llvm;

STATISTIC(NumLoops, "Number of loops with the sum in the FPU accumulator");

namespace {

class MipsR5900LoopAcc : public MachineFunctionPass {
public:
  static char ID;
  MipsR5900LoopAcc() : MachineFunctionPass(ID) {}
  StringRef getPassName() const override {
    return "R5900 FPU accumulator in loops";
  }
  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  MachineRegisterInfo *MRI = nullptr;
  const MipsInstrInfo *TII = nullptr;

  struct Sum {
    MachineInstr *Phi;
    MachineInstr *Add;
    MachineInstr *Mul;
    Register Init;
    Register Next;
  };

  bool isZero(Register Reg) const;
  bool tryLoop(MachineBasicBlock &L);
};

} // namespace

char MipsR5900LoopAcc::ID = 0;
INITIALIZE_PASS(MipsR5900LoopAcc, DEBUG_TYPE, "R5900 FPU accumulator in loops",
                false, false)

/// A register that holds +0.0.
bool MipsR5900LoopAcc::isZero(Register Reg) const {
  while (Reg.isVirtual()) {
    const MachineInstr *Def = MRI->getVRegDef(Reg);
    if (!Def)
      return false;
    if (Def->getOpcode() == Mips::MTC1)
      return Def->getOperand(1).isReg() &&
             Def->getOperand(1).getReg() == Mips::ZERO;
    if (Def->getOpcode() == Mips::COPY)
      Reg = Def->getOperand(1).getReg();
    else
      return false;
  }
  return false;
}

bool MipsR5900LoopAcc::tryLoop(MachineBasicBlock &L) {
  if (L.pred_size() != 2 || L.succ_size() != 2 || !L.isSuccessor(&L))
    return false;
  MachineBasicBlock *Pre = nullptr, *Exit = nullptr;
  for (MachineBasicBlock *P : L.predecessors())
    if (P != &L)
      Pre = P;
  for (MachineBasicBlock *S : L.successors())
    if (S != &L)
      Exit = S;
  if (!Pre || !Exit || Exit->pred_size() != 1 || Exit == Pre ||
      Exit->isEHPad() || Pre->succ_size() != 1)
    return false;

  // Nothing else in the loop may use or clobber ACC, or call out.
  for (const MachineInstr &MI : L)
    if (MI.isCall() || MI.readsRegister(Mips::FPU_ACC, nullptr) ||
        MI.modifiesRegister(Mips::FPU_ACC, nullptr))
      return false;

  SmallVector<Sum, 8> Sums;
  for (MachineInstr &Phi : L.phis()) {
    Register Dst = Phi.getOperand(0).getReg();
    if (MRI->getRegClass(Dst) != &Mips::FGR32RegClass ||
        !MRI->hasOneNonDBGUse(Dst))
      continue;
    Sum S{&Phi, nullptr, nullptr, Register(), Register()};
    for (unsigned I = 1; I + 1 < Phi.getNumOperands(); I += 2) {
      if (Phi.getOperand(I + 1).getMBB() == &L)
        S.Next = Phi.getOperand(I).getReg();
      else
        S.Init = Phi.getOperand(I).getReg();
    }
    if (!S.Next || !S.Init)
      continue;
    MachineInstr *Add = MRI->getVRegDef(S.Next);
    if (!Add || Add->getParent() != &L || Add->getOpcode() != Mips::FADD_S ||
        !Add->getFlag(MachineInstr::FmReassoc) ||
        !Add->getFlag(MachineInstr::FmNsz))
      continue;
    Register Other;
    if (Add->getOperand(1).getReg() == Dst)
      Other = Add->getOperand(2).getReg();
    else if (Add->getOperand(2).getReg() == Dst)
      Other = Add->getOperand(1).getReg();
    else
      continue;
    MachineInstr *Mul = Other.isVirtual() && MRI->hasOneNonDBGUse(Other)
                            ? MRI->getVRegDef(Other)
                            : nullptr;
    if (!Mul || Mul->getParent() != &L || Mul->getOpcode() != Mips::FMUL_S)
      continue;
    // The new sum is read only by the phi and by the exit block.
    bool Ok = true;
    for (MachineInstr &U : MRI->use_nodbg_instructions(S.Next))
      if (&U != &Phi && U.getParent() != Exit)
        Ok = false;
    if (!Ok)
      continue;
    S.Add = Add;
    S.Mul = Mul;
    Sums.push_back(S);
  }
  if (Sums.size() < 2)
    return false;

  // At most one initial value is not zero.
  Register Start;
  for (const Sum &S : Sums)
    if (!isZero(S.Init)) {
      if (Start)
        return false;
      Start = S.Init;
    }

  LLVM_DEBUG(dbgs() << "R5900 FPU ACC: loop " << L.getName() << " with "
                    << Sums.size() << " sums\n");
  const DebugLoc DL = Sums[0].Add->getDebugLoc();
  auto NewZero = [&](MachineBasicBlock &MBB, MachineBasicBlock::iterator At) {
    Register Bits = MRI->createVirtualRegister(&Mips::FGR32RegClass);
    BuildMI(MBB, At, DL, TII->get(Mips::MTC1), Bits).addReg(Mips::ZERO);
    return Bits;
  };

  // ACC = start + 0.0 before the loop.
  MachineBasicBlock::iterator PreEnd = Pre->getFirstTerminator();
  Register Z = NewZero(*Pre, PreEnd);
  BuildMI(*Pre, PreEnd, DL, TII->get(Mips::ADDA_S_R5900))
      .addReg(Start ? Start : Z)
      .addReg(Z);

  // One madda.s for each product, where the add was.
  for (const Sum &S : Sums)
    BuildMI(L, S.Add, S.Add->getDebugLoc(), TII->get(Mips::MADDA_S_R5900))
        .addReg(S.Mul->getOperand(1).getReg())
        .addReg(S.Mul->getOperand(2).getReg());

  // After the loop, ACC - 0.0*0.0 is the sum; the other partial sums are 0.
  MachineBasicBlock::iterator ExitBegin = Exit->getFirstNonPHI();
  Register Zero = NewZero(*Exit, ExitBegin);
  Register Total = MRI->createVirtualRegister(&Mips::FGR32RegClass);
  BuildMI(*Exit, ExitBegin, DL, TII->get(Mips::MSUB_S_R5900), Total)
      .addReg(Zero)
      .addReg(Zero);
  for (unsigned I = 0, E = Sums.size(); I != E; ++I)
    for (MachineOperand &MO :
         llvm::make_early_inc_range(MRI->use_operands(Sums[I].Next)))
      if (MO.getParent()->getParent() == Exit)
        MO.setReg(I == 0 ? Total : Zero);

  for (const Sum &S : Sums) {
    S.Phi->eraseFromParent();
    S.Add->eraseFromParent();
    S.Mul->eraseFromParent();
  }
  L.addLiveIn(Mips::FPU_ACC);
  Exit->addLiveIn(Mips::FPU_ACC);
  ++NumLoops;
  return true;
}

bool MipsR5900LoopAcc::runOnMachineFunction(MachineFunction &MF) {
  const auto &STI = MF.getSubtarget<MipsSubtarget>();
  if (!STI.isR5900() || STI.useSoftFloat())
    return false;
  MRI = &MF.getRegInfo();
  TII = STI.getInstrInfo();
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF)
    Changed |= tryLoop(MBB);
  return Changed;
}

FunctionPass *llvm::createMipsR5900LoopAccPass() {
  return new MipsR5900LoopAcc();
}
