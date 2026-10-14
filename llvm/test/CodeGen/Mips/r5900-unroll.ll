; RUN: opt -mtriple=mips64el-unknown-none -mcpu=r5900 -passes=loop-unroll -S < %s | FileCheck %s --check-prefix=R5900
; RUN: opt -mtriple=mips64el-unknown-none -mcpu=mips64r2 -passes=loop-unroll -S < %s | FileCheck %s --check-prefix=OTHER

; The R5900 partially unrolls small loops with a runtime trip count.
define void @scale(ptr %p, i32 %n) {
; R5900-LABEL: @scale(
; R5900:       fmul float
; R5900:       fmul float
; OTHER-LABEL: @scale(
; OTHER-NOT:   fmul float{{.*}}
; OTHER:       fmul float
; OTHER-NOT:   fmul float
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %a = getelementptr float, ptr %p, i32 %i
  %v = load float, ptr %a
  %m = fmul float %v, 2.0
  store float %m, ptr %a
  %inc = add i32 %i, 1
  %c = icmp ult i32 %inc, %n
  br i1 %c, label %loop, label %exit
exit:
  ret void
}
