; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s
;
; The R5900 scheduling model keeps the 4-cycle FPU result latency in mind, so
; independent loads are issued ahead of the multiplies that use them.

define float @test_dot2(ptr %a, ptr %b) {
; CHECK-LABEL: test_dot2:
; CHECK:      lwc1
; CHECK-NEXT: lwc1
; CHECK-NEXT: lwc1
; CHECK-NEXT: lwc1
; CHECK:      mul.s
; CHECK:      mul.s
  %a0 = load float, ptr %a
  %b0 = load float, ptr %b
  %pa1 = getelementptr float, ptr %a, i64 1
  %pb1 = getelementptr float, ptr %b, i64 1
  %a1 = load float, ptr %pa1
  %b1 = load float, ptr %pb1
  %m0 = fmul float %a0, %b0
  %m1 = fmul float %a1, %b1
  %s = fsub float %m0, %m1
  ret float %s
}
