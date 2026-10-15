; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O2 < %s | FileCheck %s

; The R5900 takes about six cycles from c.cond.s to bc1f. The updates of x and
; z, used only after the bounce branch, stay ahead of it to run in that gap.

define void @particle(ptr %px, ptr %py, ptr %pz, ptr %vx, ptr %vy, ptr %vz) {
; CHECK-LABEL: particle:
; CHECK:       # %loop
; CHECK:         add.s
; CHECK-NOT:     c.olt.s
; CHECK:         add.s
; CHECK-NOT:     c.olt.s
; CHECK:         add.s
; CHECK:         c.olt.s
; CHECK:         bc1f
entry:
  %x0 = load float, ptr %px, align 4
  %y0 = load float, ptr %py, align 4
  %z0 = load float, ptr %pz, align 4
  %vx0 = load float, ptr %vx, align 4
  %vy0 = load float, ptr %vy, align 4
  %vz0 = load float, ptr %vz, align 4
  br label %loop

loop:
  %f = phi i32 [ 0, %entry ], [ %f.next, %latch ]
  %vyc = phi float [ %vy0, %entry ], [ %vy3, %latch ]
  %vxc = phi float [ %vx0, %entry ], [ %vx3, %latch ]
  %x = phi float [ %x0, %entry ], [ %x1, %latch ]
  %y = phi float [ %y0, %entry ], [ %y3, %latch ]
  %vzc = phi float [ %vz0, %entry ], [ %vz3, %latch ]
  %z = phi float [ %z0, %entry ], [ %z1, %latch ]
  %vy1 = fadd float %vyc, -1.633333e-01
  %x1 = call float @llvm.fmuladd.f32(float %vxc, float 1.666667e-02, float %x)
  %y1 = call float @llvm.fmuladd.f32(float %vy1, float 1.666667e-02, float %y)
  %z1 = call float @llvm.fmuladd.f32(float %vzc, float 1.666667e-02, float %z)
  %below = fcmp olt float %y1, 0.0
  br i1 %below, label %bounce, label %clamp.test

bounce:
  %y2 = fneg float %y1
  %vy2 = fmul float %vy1, -8.000000e-01
  br label %clamp.test

clamp.test:
  %y3 = phi float [ %y2, %bounce ], [ %y1, %loop ]
  %vy3.0 = phi float [ %vy2, %bounce ], [ %vy1, %loop ]
  %zz = fmul float %z1, %z1
  %d2 = call float @llvm.fmuladd.f32(float %x1, float %x1, float %zz)
  %far = fcmp ogt float %d2, 1.000000e+02
  br i1 %far, label %clamp, label %latch

clamp:
  %s = call float @llvm.sqrt.f32(float %d2)
  %inv = fdiv float 1.0, %s
  %nx = fneg float %x1
  %vx2 = fmul float %inv, %nx
  %nz = fneg float %z1
  %vz2 = fmul float %inv, %nz
  br label %latch

latch:
  %vx3 = phi float [ %vx2, %clamp ], [ %vxc, %clamp.test ]
  %vz3 = phi float [ %vz2, %clamp ], [ %vzc, %clamp.test ]
  %vy3 = phi float [ %vy3.0, %clamp ], [ %vy3.0, %clamp.test ]
  %f.next = add nuw nsw i32 %f, 1
  %done = icmp eq i32 %f.next, 30
  br i1 %done, label %exit, label %loop

exit:
  store float %x1, ptr %px, align 4
  store float %y3, ptr %py, align 4
  store float %z1, ptr %pz, align 4
  store float %vx3, ptr %vx, align 4
  store float %vy3, ptr %vy, align 4
  store float %vz3, ptr %vz, align 4
  ret void
}

declare float @llvm.fmuladd.f32(float, float, float)
declare float @llvm.sqrt.f32(float)

; Ahead of an integer branch there is no gap to fill, so the multiply still
; sinks to the only block that uses it.
define float @int_branch(float %a, float %b, i32 %c) {
; CHECK-LABEL: int_branch:
; CHECK:         beqz
; CHECK-NOT:     mul.s
; CHECK:         jr $ra
; CHECK:         mul.s $f0, $f12, $f13
entry:
  %m = fmul float %a, %b
  %t = icmp eq i32 %c, 0
  br i1 %t, label %use, label %out
use:
  %r = fadd float %m, %a
  ret float %r
out:
  ret float %a
}
