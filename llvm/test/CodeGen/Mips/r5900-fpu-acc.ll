; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s
;
; A chain of multiplies and adds becomes mula.s, madda.s and madd.s.

define float @dot3(float %a0, float %a1, float %a2, float %b0, float %b1, float %b2) {
; CHECK-LABEL: dot3:
; CHECK:      mula.s
; CHECK:      madda.s
; CHECK:      madd.s
  %m0 = fmul float %a0, %b0
  %m1 = fmul float %a1, %b1
  %m2 = fmul float %a2, %b2
  %s0 = fadd float %m0, %m1
  %s1 = fadd float %s0, %m2
  ret float %s1
}

; A product with another reader stays a multiply.
define float @shared(float %a, float %b, float %c, float %d, ptr %p) {
; CHECK-LABEL: shared:
; CHECK-NOT:  mula.s
  %m0 = fmul float %a, %b
  %m1 = fmul float %c, %d
  store float %m0, ptr %p
  %s = fadd float %m0, %m1
  ret float %s
}
