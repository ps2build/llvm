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

unsigned MipsTTIImpl::getMaxInterleaveFactor(ElementCount VF,
                                            bool HasUnorderedReductions) const {
  if (ST->isR5900() && !ST->hasMSA())
    return 1;
  return BaseT::getMaxInterleaveFactor(VF, HasUnorderedReductions);
}

bool MipsTTIImpl::hasDivRemOp(Type *DataType, bool IsSigned) const {
  EVT VT = TLI->getValueType(DL, DataType);
  return TLI->isOperationLegalOrCustom(IsSigned ? ISD::SDIVREM : ISD::UDIVREM,
                                       VT);
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
  return BaseT::getArithmeticInstrCost(Opcode, Ty, CostKind, Op1Info, Op2Info,
                                       Args, CxtI);
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
