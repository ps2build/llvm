# The PS2 triple implies the R5900 and the n32 ABI.

# RUN: llvm-mc -filetype=obj -triple=mips64r5900el-ps2-elf %s -o %t.o
# RUN: llvm-readelf -h %t.o | FileCheck %s

# CHECK: Class: ELF32
# CHECK: Flags: {{.*}} abi2, 5900, mips3

madd1 $3, $4, $5
