; RUN: opt -passes='default<O3>' -mtriple=mips64r5900el-ps2-elf -S < %s | FileCheck %s

; The R5900 vectorizes the remainder of a widely interleaved i16 reduction with
; an 8-wide epilogue instead of a long scalar tail.
; CHECK: vec.epilog.vector.body

target datalayout = "e-m:e-p:32:32-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "mips64r5900el-ps2-unknown-elf"

define signext i16 @hmax_i16(ptr noundef %a, i32 noundef signext %n) #0 {
entry:
  %first = load i16, ptr %a, align 2
  %smax = call i32 @llvm.smax.i32(i32 %n, i32 1)
  br label %for.cond

for.cond:
  %m = phi i16 [ %first, %entry ], [ %r, %for.body ]
  %i = phi i32 [ 1, %entry ], [ %inc, %for.body ]
  %cmp = icmp ne i32 %i, %smax
  br i1 %cmp, label %for.body, label %for.end

for.body:
  %p = getelementptr inbounds i16, ptr %a, i32 %i
  %v = load i16, ptr %p, align 2
  %c = icmp sgt i16 %v, %m
  %r = select i1 %c, i16 %v, i16 %m
  %inc = add nuw nsw i32 %i, 1
  br label %for.cond, !llvm.loop !0

for.end:
  ret i16 %m
}

declare i32 @llvm.smax.i32(i32, i32)

attributes #0 = { nounwind "target-cpu"="r5900" "target-features"="+r5900,-noabicalls" }

!0 = distinct !{!0, !1}
!1 = !{!"llvm.loop.mustprogress"}
