# REQUIRES: mips
## In a relocatable link the addend of a REL R_MIPS_HI16 against a section
## symbol is completed by its paired R_MIPS_LO16. The second copy of .text
## starts at 0x7e00, so the address of "target" becomes 0x82c4: the low half
## is negative as a signed 16-bit value and the high half must be 1, not 0.

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux -o %t.o %s
# RUN: ld.lld -r -o %t %t.o %t.o
# RUN: llvm-objdump --no-print-imm-hex -d -r --no-show-raw-insn %t | FileCheck %s

# CHECK:      lui     $2, 0
# CHECK-NEXT:         R_MIPS_HI16  .text
# CHECK-NEXT: addiu   $2, $2, 1220
# CHECK-NEXT:         R_MIPS_LO16  .text
# CHECK:      lui     $2, 1
# CHECK-NEXT:         R_MIPS_HI16  .text
# CHECK-NEXT: addiu   $2, $2, -32060
# CHECK-NEXT:         R_MIPS_LO16  .text

  .text
  .space 0x494
  lui    $2, %hi(target)
  addiu  $2, $2, %lo(target)
  .space 0x28
target:
  nop
  .space 0x7938
