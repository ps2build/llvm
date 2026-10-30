; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' -S %s | FileCheck %s
; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' %s | llc -O2 -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -o /dev/null

target datalayout = "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S64"

; The run-time check must be built without leaving invalid debug locations.
; CHECK-LABEL: @f(
; CHECK: mmi.align.check:
define i1 @f(ptr %a, i32 %n) {
  br label %loop

loop:
  %i = phi i32 [ %i.next, %loop ], [ %n, %0 ]
  %i.next = add i32 %i, -1
  %p = getelementptr [4 x i8], ptr %a, i32 %i.next
  %v = load i32, ptr %p, align 4
  %c = icmp sgt i32 %i, 0
  br i1 %c, label %loop, label %exit

exit:
  %r = icmp eq i32 %v, 0
  ret i1 %r
}
