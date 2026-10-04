; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s

define float @test_fmax(float %a, float %b) {
; CHECK-LABEL: test_fmax:
; CHECK: max.s
  %r = call float @llvm.maxnum.f32(float %a, float %b)
  ret float %r
}

define float @test_fmin(float %a, float %b) {
; CHECK-LABEL: test_fmin:
; CHECK: min.s
  %r = call float @llvm.minnum.f32(float %a, float %b)
  ret float %r
}

define float @test_rsqrt(float %x) {
; CHECK-LABEL: test_rsqrt:
; CHECK: rsqrt.s
  %s = call float @llvm.sqrt.f32(float %x)
  %r = fdiv float 1.0, %s
  ret float %r
}

define float @test_div_sqrt(float %a, float %x) {
; CHECK-LABEL: test_div_sqrt:
; CHECK: rsqrt.s $f0, $f12, $f13
  %s = call float @llvm.sqrt.f32(float %x)
  %r = fdiv float %a, %s
  ret float %r
}

declare float @llvm.maxnum.f32(float, float)
declare float @llvm.minnum.f32(float, float)
declare float @llvm.sqrt.f32(float)

; rsqrt.s only replaces a division by a sqrt that has no other users.
define float @test_rsqrt_shared(float %a, float %x, ptr %p) {
; CHECK-LABEL: test_rsqrt_shared:
; CHECK-NOT: rsqrt.s
; CHECK: sqrt.s
; CHECK: div.s
  %s = call float @llvm.sqrt.f32(float %x)
  store float %s, ptr %p
  %r = fdiv float %a, %s
  ret float %r
}

define float @test_rsqrt_neg(float %a, float %x) {
; CHECK-LABEL: test_rsqrt_neg:
; CHECK: neg.s
; CHECK: rsqrt.s
  %s = call float @llvm.sqrt.f32(float %x)
  %n = fneg float %s
  %r = fdiv float %a, %n
  ret float %r
}
