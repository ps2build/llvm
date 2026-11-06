; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -O2 < %s | FileCheck %s

; A widening 16x16->32 multiply uses one PMULTH and reads both results.
define void @mul_widen(ptr %a, ptr %b, ptr %o) {
; CHECK-LABEL: mul_widen:
; CHECK:       pmulth
; CHECK-NEXT:  pmflo
; CHECK-NEXT:  pmfhi
; CHECK-NOT:   mult
  %x = load <8 x i16>, ptr %a, align 16
  %y = load <8 x i16>, ptr %b, align 16
  %sx = sext <8 x i16> %x to <8 x i32>
  %sy = sext <8 x i16> %y to <8 x i32>
  %m = mul <8 x i32> %sx, %sy
  store <8 x i32> %m, ptr %o, align 16
  ret void
}
