; REQUIRES: asserts
; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O3 -stats < %s 2>&1 | FileCheck %s --check-prefix=ON
; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O3 -mips-r5900-pipeliner=false -stats < %s 2>&1 | FileCheck %s --check-prefix=OFF

; A single-block FPU loop is software pipelined on the R5900; the option turns
; it off.
; ON: {{[0-9]+}} pipeliner{{.*}}software pipelined
; OFF-NOT: software pipelined

define void @saxpy(ptr noalias %y, ptr noalias %x, float %a, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %px = getelementptr float, ptr %x, i32 %i
  %py = getelementptr float, ptr %y, i32 %i
  %vx = load float, ptr %px
  %vy = load float, ptr %py
  %m = fmul float %vx, %a
  %s = fadd float %vy, %m
  store float %s, ptr %py
  %i.next = add i32 %i, 1
  %e = icmp eq i32 %i.next, %n
  br i1 %e, label %exit, label %loop
exit:
  ret void
}
