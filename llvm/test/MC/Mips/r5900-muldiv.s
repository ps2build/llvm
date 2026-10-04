# RUN: llvm-mc %s -triple=mips64el-unknown-linux -mcpu=r5900 -show-encoding | FileCheck %s
#
# R5900 multiply/divide forms; encodings match GNU as -march=r5900.

madd   $4, $5
# CHECK: madd $4, $5 # encoding: [0x00,0x00,0x85,0x70]
maddu  $4, $5
# CHECK: maddu $4, $5 # encoding: [0x01,0x00,0x85,0x70]
madd   $3, $4, $5
# CHECK: madd $3, $4, $5 # encoding: [0x00,0x18,0x85,0x70]
maddu  $3, $4, $5
# CHECK: maddu $3, $4, $5 # encoding: [0x01,0x18,0x85,0x70]
madd1  $3, $4, $5
# CHECK: madd1 $3, $4, $5 # encoding: [0x20,0x18,0x85,0x70]
maddu1 $3, $4, $5
# CHECK: maddu1 $3, $4, $5 # encoding: [0x21,0x18,0x85,0x70]
mult1  $3, $4, $5
# CHECK: mult1 $3, $4, $5 # encoding: [0x18,0x18,0x85,0x70]
multu1 $3, $4, $5
# CHECK: multu1 $3, $4, $5 # encoding: [0x19,0x18,0x85,0x70]
mult   $3, $4, $5
# CHECK: mult $3, $4, $5 # encoding: [0x18,0x18,0x85,0x00]
multu  $3, $4, $5
# CHECK: multu $3, $4, $5 # encoding: [0x19,0x18,0x85,0x00]
div1   $0, $4, $5
# CHECK: div1 $zero, $4, $5 # encoding: [0x1a,0x00,0x85,0x70]
divu1  $0, $4, $5
# CHECK: divu1 $zero, $4, $5 # encoding: [0x1b,0x00,0x85,0x70]
