; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s
;
; Compares feeding a select or a branch use only the conditions the R5900 FPU
; implements (c.f, c.eq, c.lt, c.le), never c.un, c.ult, c.ule or c.ueq.

define float @test_select_ule(float %a, float %b) {
; CHECK-LABEL: test_select_ule:
; CHECK-NOT: c.u
; CHECK: c.olt.s $f13, $f12
; CHECK: bc1
  %c = fcmp ule float %a, %b
  %r = select i1 %c, float %b, float %a
  ret float %r
}

define float @test_select_ult(float %a, float %b) {
; CHECK-LABEL: test_select_ult:
; CHECK-NOT: c.u
; CHECK: c.ole.s $f13, $f12
; CHECK: bc1
  %c = fcmp ult float %a, %b
  %r = select i1 %c, float %b, float %a
  ret float %r
}

define float @test_select_ogt(float %a, float %b) {
; CHECK-LABEL: test_select_ogt:
; CHECK-NOT: c.u
; CHECK: c.olt.s $f13, $f12
; CHECK: bc1
  %c = fcmp ogt float %a, %b
  %r = select i1 %c, float %a, float %b
  ret float %r
}

define i32 @test_branch_uge(float %a, float %b) {
; CHECK-LABEL: test_branch_uge:
; CHECK-NOT: c.u
; CHECK: c.olt.s $f12, $f13
; CHECK: bc1
  %c = fcmp uge float %a, %b
  br i1 %c, label %t, label %f
t:
  ret i32 1
f:
  ret i32 0
}
