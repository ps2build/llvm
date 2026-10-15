; RUN: opt -mtriple=mips64el-unknown-none -mcpu=r5900 -passes=loop-unroll-and-jam -S < %s | FileCheck %s --check-prefix=R5900
; RUN: opt -mtriple=mips64el-unknown-none -mcpu=mips64r2 -passes=loop-unroll-and-jam -allow-unroll-and-jam -S < %s | FileCheck %s --check-prefix=OTHER

@a = global [1024 x float] zeroinitializer

; The R5900 jams the outer loop even when the inner loop body has a branch.
define void @step(i32 %frames) {
; R5900-LABEL: @step(
; R5900:       fmul float
; R5900:       fmul float
; R5900:       fmul float
; R5900:       fmul float
; R5900:       fmul float
; R5900:       fmul float
; OTHER-LABEL: @step(
; OTHER:       fmul float
; OTHER-NOT:   fmul float
entry:
  br label %outer
outer:
  %f = phi i32 [ 0, %entry ], [ %f.next, %outer.latch ]
  br label %inner
inner:
  %i = phi i32 [ 0, %outer ], [ %i.next, %inner.latch ]
  %p = getelementptr float, ptr @a, i32 %i
  %v = load float, ptr %p
  %m = fmul float %v, 2.0
  %neg = fcmp olt float %m, 0.0
  br i1 %neg, label %flip, label %inner.latch
flip:
  %n = fneg float %m
  store float %n, ptr %p
  br label %inner.latch
inner.latch:
  %i.next = add nuw i32 %i, 1
  %c = icmp ult i32 %i.next, 1024
  br i1 %c, label %inner, label %outer.latch
outer.latch:
  %f.next = add nuw i32 %f, 1
  %d = icmp ult i32 %f.next, %frames
  br i1 %d, label %outer, label %exit
exit:
  ret void
}
