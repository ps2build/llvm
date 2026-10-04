# RUN: llvm-mc %s -triple=mips64el-unknown-linux -mcpu=r5900 -show-encoding | FileCheck %s
#
# R5900 COP1 extensions; encodings match GNU as -march=r5900.

rsqrt.s $f1, $f2, $f3
# CHECK: rsqrt.s $f1, $f2, $f3 # encoding: [0x56,0x10,0x03,0x46]
max.s   $f1, $f2, $f3
# CHECK: max.s $f1, $f2, $f3 # encoding: [0x68,0x10,0x03,0x46]
min.s   $f1, $f2, $f3
# CHECK: min.s $f1, $f2, $f3 # encoding: [0x69,0x10,0x03,0x46]
adda.s  $f2, $f3
# CHECK: adda.s $f2, $f3 # encoding: [0x18,0x10,0x03,0x46]
suba.s  $f2, $f3
# CHECK: suba.s $f2, $f3 # encoding: [0x19,0x10,0x03,0x46]
mula.s  $f2, $f3
# CHECK: mula.s $f2, $f3 # encoding: [0x1a,0x10,0x03,0x46]
madd.s  $f1, $f2, $f3
# CHECK: madd.s $f1, $f2, $f3 # encoding: [0x5c,0x10,0x03,0x46]
msub.s  $f1, $f2, $f3
# CHECK: msub.s $f1, $f2, $f3 # encoding: [0x5d,0x10,0x03,0x46]
madda.s $f2, $f3
# CHECK: madda.s $f2, $f3 # encoding: [0x1e,0x10,0x03,0x46]
msuba.s $f2, $f3
# CHECK: msuba.s $f2, $f3 # encoding: [0x1f,0x10,0x03,0x46]
