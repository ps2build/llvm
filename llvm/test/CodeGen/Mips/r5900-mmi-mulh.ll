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

; A sum of widening multiplies accumulates in HI/LO with PMADDH.
define void @mul_add(ptr %a, ptr %b, ptr %c, ptr %d, ptr %o) {
; CHECK-LABEL: mul_add:
; CHECK:       pmulth
; CHECK-NEXT:  pmaddh
; CHECK-NEXT:  pmflo
; CHECK-NEXT:  pmfhi
  %x = load <8 x i16>, ptr %a, align 16
  %y = load <8 x i16>, ptr %b, align 16
  %z = load <8 x i16>, ptr %c, align 16
  %w = load <8 x i16>, ptr %d, align 16
  %sx = sext <8 x i16> %x to <8 x i32>
  %sy = sext <8 x i16> %y to <8 x i32>
  %sz = sext <8 x i16> %z to <8 x i32>
  %sw = sext <8 x i16> %w to <8 x i32>
  %m = mul <8 x i32> %sx, %sy
  %n = mul <8 x i32> %sz, %sw
  %s = add <8 x i32> %m, %n
  store <8 x i32> %s, ptr %o, align 16
  ret void
}
