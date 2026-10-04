; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s
;
; R5900 single-precision arithmetic uses the hardware FPU, with or without
; fast-math flags, and never calls the soft-float routines.

define float @test_fadd(float %a, float %b) {
; CHECK-LABEL: test_fadd:
; CHECK-NOT: jal
; CHECK: add.s
  %result = fadd float %a, %b
  ret float %result
}

define float @test_fsub(float %a, float %b) {
; CHECK-LABEL: test_fsub:
; CHECK-NOT: jal
; CHECK: sub.s
  %result = fsub float %a, %b
  ret float %result
}

define float @test_fmul(float %a, float %b) {
; CHECK-LABEL: test_fmul:
; CHECK-NOT: jal
; CHECK: mul.s
  %result = fmul float %a, %b
  ret float %result
}

define float @test_fdiv(float %a, float %b) {
; CHECK-LABEL: test_fdiv:
; CHECK-NOT: jal
; CHECK: div.s
  %result = fdiv float %a, %b
  ret float %result
}

define float @test_fsqrt(float %a) {
; CHECK-LABEL: test_fsqrt:
; CHECK-NOT: jal
; CHECK: sqrt.s
  %result = call float @llvm.sqrt.f32(float %a)
  ret float %result
}

define float @test_fadd_nnan_ninf(float %a, float %b) {
; CHECK-LABEL: test_fadd_nnan_ninf:
; CHECK: add.s
  %result = fadd nnan ninf float %a, %b
  ret float %result
}

define float @test_fmul_nnan_ninf(float %a, float %b) {
; CHECK-LABEL: test_fmul_nnan_ninf:
; CHECK: mul.s
  %result = fmul nnan ninf float %a, %b
  ret float %result
}

declare float @llvm.sqrt.f32(float)
