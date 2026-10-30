; RUN: llc -mtriple=mips64r5900el-ps2-elf -O2 < %s | FileCheck %s

; CHECK-LABEL: add_w:
; CHECK: lq
; CHECK: lq
; CHECK: paddw
; CHECK: sq
define void @add_w(ptr align 16 %a, ptr align 16 %b, ptr align 16 %c) {
  %x = load <4 x i32>, ptr %a, align 16
  %y = load <4 x i32>, ptr %b, align 16
  %z = add <4 x i32> %x, %y
  store <4 x i32> %z, ptr %c, align 16
  ret void
}

; CHECK-LABEL: sub_b:
; CHECK: psubb
define void @sub_b(ptr align 16 %a, ptr align 16 %b, ptr align 16 %c) {
  %x = load <16 x i8>, ptr %a, align 16
  %y = load <16 x i8>, ptr %b, align 16
  %z = sub <16 x i8> %x, %y
  store <16 x i8> %z, ptr %c, align 16
  ret void
}

; CHECK-LABEL: logic:
; CHECK: pand
; CHECK: por
; CHECK: pxor
define void @logic(ptr align 16 %a, ptr align 16 %b, ptr align 16 %c) {
  %x = load <8 x i16>, ptr %a, align 16
  %y = load <8 x i16>, ptr %b, align 16
  %p = and <8 x i16> %x, %y
  %z = load <8 x i16>, ptr %c, align 16
  %q = or <8 x i16> %p, %z
  %r = xor <8 x i16> %q, %y
  store <8 x i16> %r, ptr %c, align 16
  ret void
}

; CHECK-LABEL: nor_d:
; CHECK: pnor
define void @nor_d(ptr align 16 %a, ptr align 16 %b, ptr align 16 %c) {
  %x = load <2 x i64>, ptr %a, align 16
  %y = load <2 x i64>, ptr %b, align 16
  %o = or <2 x i64> %x, %y
  %n = xor <2 x i64> %o, <i64 -1, i64 -1>
  store <2 x i64> %n, ptr %c, align 16
  ret void
}

; Unaligned vectors must not use lq/sq directly.
; CHECK-LABEL: unaligned:
; CHECK: ldl
; CHECK: ldr
; CHECK: sdl
; CHECK: sdr
define void @unaligned(ptr %a, ptr %c) {
  %x = load <4 x i32>, ptr %a, align 1
  store <4 x i32> %x, ptr %c, align 1
  ret void
}

; CHECK-LABEL: zero:
; CHECK: por {{.*}}$zero, $zero
define void @zero(ptr align 16 %c) {
  store <4 x i32> zeroinitializer, ptr %c, align 16
  ret void
}
