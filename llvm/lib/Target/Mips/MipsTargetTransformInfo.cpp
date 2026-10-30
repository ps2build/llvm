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

// A 16-byte aligned 128-bit vector is one lq/sq; an unaligned one is two
// ldl/ldr (sdl/sdr) pairs joined or split by pcpyld/pcpyud; the cost is
// set from rig timings, where a 4 x i32 add loop on unaligned data ran 39%
// slower than scalar. A 32-bit-element access aligned to its element is
// costed as aligned because MipsMMIAlign versions the vector loop on a
// run-time check.
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
               : 24;
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
  bool HasLoad = false;
  for (const Instruction &I : *L->getHeader())
    if (const auto *LI = dyn_cast<LoadInst>(&I)) {
      if (DL.getTypeStoreSize(LI->getType()) < 4)
        return;
      HasLoad = true;
    }
  if (!HasLoad)
    return;
  UP.Partial = true;
  UP.Runtime = true;
  UP.PartialThreshold = 120;
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
      VTy->getPrimitiveSizeInBits().getFixedValue() == 128) {
    unsigned EltBits = VTy->getScalarSizeInBits();
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
