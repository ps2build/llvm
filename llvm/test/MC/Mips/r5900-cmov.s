# RUN: llvm-mc %s -triple=mips64el-unknown-linux -mcpu=r5900 -show-encoding | FileCheck %s
# RUN: not llvm-mc %s -triple=mips64el-unknown-linux -mcpu=r5900 --defsym INVALID=1 2>&1 | FileCheck %s --check-prefix=ERR
# RUN: not llvm-mc %s -triple=mips64el-unknown-linux -mcpu=mips3 2>&1 | FileCheck %s --check-prefix=MIPS3
#
# The R5900 has the integer conditional moves but not the FPU ones.

movz $3, $4, $5
# CHECK: movz $3, $4, $5 # encoding: [0x0a,0x18,0x85,0x00]
# MIPS3: :[[@LINE-2]]:1: error: instruction requires a CPU feature not currently enabled
movn $3, $4, $5
# CHECK: movn $3, $4, $5 # encoding: [0x0b,0x18,0x85,0x00]
# MIPS3: :[[@LINE-2]]:1: error: instruction requires a CPU feature not currently enabled

.ifdef INVALID
movz.s $f1, $f2, $3
# ERR: :[[@LINE-1]]:1: error: instruction requires a CPU feature not currently enabled
movn.s $f1, $f2, $3
# ERR: :[[@LINE-1]]:1: error: instruction requires a CPU feature not currently enabled
movt $3, $4, $fcc0
# ERR: :[[@LINE-1]]:1: error: instruction requires a CPU feature not currently enabled
movf.s $f1, $f2, $fcc0
# ERR: :[[@LINE-1]]:1: error: instruction requires a CPU feature not currently enabled
.endif
