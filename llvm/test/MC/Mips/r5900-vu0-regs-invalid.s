# VU0 register names are registers only when VU0 is present.
# RUN: not llvm-mc %s -triple=mips64el-unknown-linux -mcpu=mips3 2>&1 | FileCheck %s

        vadd.xyz $vf1, $vf2, $vf3  # CHECK: :[[@LINE]]:18: error: invalid operand for instruction
