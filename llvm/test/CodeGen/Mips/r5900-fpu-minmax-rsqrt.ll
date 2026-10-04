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
