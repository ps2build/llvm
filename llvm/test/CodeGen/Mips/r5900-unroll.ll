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

; Loops without a load, and loops over bytes, are usually short; leave them rolled.
; R5900-LABEL: @fill(
; R5900:       store i32
; R5900-NOT:   store i32
define void @fill(ptr %p, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %a = getelementptr i32, ptr %p, i32 %i
  store i32 7, ptr %a
  %inc = add i32 %i, 1
  %c = icmp ult i32 %inc, %n
  br i1 %c, label %loop, label %exit
exit:
  ret void
}

; R5900-LABEL: @copy_bytes(
; R5900:       load i8
; R5900-NOT:   load i8
define void @copy_bytes(ptr %d, ptr %s, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %sa = getelementptr i8, ptr %s, i32 %i
  %da = getelementptr i8, ptr %d, i32 %i
  %v = load i8, ptr %sa
  store i8 %v, ptr %da
  %inc = add i32 %i, 1
  %c = icmp ult i32 %inc, %n
  br i1 %c, label %loop, label %exit
exit:
  ret void
}
