# RUN: llvm-mc %s -triple=mips64el-unknown-linux -mcpu=r5900 -show-encoding | FileCheck %s

pref 0, 0($t0)
# CHECK: pref 0, 0($12) # encoding: [0x00,0x00,0x80,0xcd]
pref 0, -16($sp)
# CHECK: pref 0, -16($sp) # encoding: [0xf0,0xff,0xa0,0xcf]
