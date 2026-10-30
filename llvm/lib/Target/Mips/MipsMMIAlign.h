//===-- MipsMMIAlign.h - Align vectorized loops for MMI lq/sq ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The vectorizer gives a wide access the alignment of the scalar access it
// replaces, so a loop over int arrays reaches the backend with align 4 and
// the R5900 has to use the slower ldl/ldr pairs. This pass guards the vector
// loop with a run-time check that every access is 16-byte aligned, sends
// misaligned inputs to the scalar remainder loop, and marks the accesses in
// the guarded vector loop as aligned so they select lq/sq.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_MIPS_MIPSMMIALIGN_H
#define LLVM_LIB_TARGET_MIPS_MIPSMMIALIGN_H

#include "llvm/IR/PassManager.h"

namespace llvm {

class MipsTargetMachine;

class MipsMMIAlignPass : public OptionalPassInfoMixin<MipsMMIAlignPass> {
  const MipsTargetMachine &TM;

public:
  explicit MipsMMIAlignPass(const MipsTargetMachine &TM) : TM(TM) {}
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);
};

} // end namespace llvm

#endif
