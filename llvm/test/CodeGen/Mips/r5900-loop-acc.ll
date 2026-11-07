; RUN: llc -mtriple=mips64el -mcpu=r5900 -O2 < %s | FileCheck %s
; RUN: llc -mtriple=mips64el -mcpu=r5900 -O0 < %s | FileCheck %s --check-prefix=O0

; A reassociable dot product with two partial sums keeps its sum in the FPU
; accumulator across the loop.
define float @dot(ptr %a, ptr %b, i32 %n) {
; CHECK-LABEL: dot:
; CHECK: adda.s
; CHECK: madda.s
; CHECK: madda.s
; CHECK-NOT: add.s
; CHECK: msub.s
; O0-LABEL: dot:
; O0-NOT: madda.s
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %s0 = phi float [ 0.0, %entry ], [ %s0.next, %loop ]
  %s1 = phi float [ 0.0, %entry ], [ %s1.next, %loop ]
  %p0 = getelementptr float, ptr %a, i32 %i
  %q0 = getelementptr float, ptr %b, i32 %i
  %x0 = load float, ptr %p0
  %y0 = load float, ptr %q0
  %m0 = fmul reassoc nsz float %x0, %y0
  %s0.next = fadd reassoc nsz float %s0, %m0
  %j = or i32 %i, 1
  %p1 = getelementptr float, ptr %a, i32 %j
  %q1 = getelementptr float, ptr %b, i32 %j
  %x1 = load float, ptr %p1
  %y1 = load float, ptr %q1
  %m1 = fmul reassoc nsz float %x1, %y1
  %s1.next = fadd reassoc nsz float %s1, %m1
  %i.next = add i32 %i, 2
  %c = icmp slt i32 %i.next, %n
  br i1 %c, label %loop, label %exit
exit:
  %r = fadd reassoc nsz float %s0.next, %s1.next
  ret float %r
}
