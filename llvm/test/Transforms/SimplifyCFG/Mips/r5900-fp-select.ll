; RUN: opt -passes=simplifycfg -mtriple=mips64el-unknown-elf -mcpu=r5900 -S < %s | FileCheck %s --check-prefix=R5900
; RUN: opt -passes=simplifycfg -mtriple=mips64el-unknown-elf -mcpu=mips3 -S < %s | FileCheck %s --check-prefix=MIPS3

; The R5900 FPU has no conditional move and a 4-cycle latency, so the if is
; kept as a branch rather than turned into two float selects.

define void @bounce(ptr %py, ptr %vy) {
; R5900-LABEL: @bounce(
; R5900:         br i1 %neg, label %if.then, label %if.end
; R5900-NOT:     select
; MIPS3-LABEL: @bounce(
; MIPS3:         select i1 %neg
; MIPS3:         select i1 %neg
entry:
  %y = load float, ptr %py, align 4
  %v = load float, ptr %vy, align 4
  %neg = fcmp olt float %y, 0.0
  br i1 %neg, label %if.then, label %if.end

if.then:
  %y2 = fneg float %y
  %v2 = fmul float %v, -8.000000e-01
  br label %if.end

if.end:
  %y3 = phi float [ %y2, %if.then ], [ %y, %entry ]
  %v3 = phi float [ %v2, %if.then ], [ %v, %entry ]
  store float %y3, ptr %py, align 4
  store float %v3, ptr %vy, align 4
  ret void
}
