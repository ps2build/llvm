; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O2 < %s | FileCheck %s

; The R5900 pairs a store only with a non-store, so the four stores of one
; iteration are best spread among the ALU work. The R5900 schedules from the top
; before register allocation, which does not spread them yet (TODO), so this only
; checks that the loop keeps its four stores.

define void @packet(ptr %out, i32 %n) {
; CHECK-LABEL: packet:
; CHECK:       .LBB0_2:
; CHECK-DAG:    sd $6, 8($2)
; CHECK-DAG:    sd $zero, 24($2)
; CHECK-DAG:    sd $1, 0($2)
; CHECK-DAG:    sd $1, 16($2)
entry:
  %cmp = icmp eq i32 %n, 0
  br i1 %cmp, label %exit, label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %p = phi ptr [ %out, %entry ], [ %p.next, %loop ]
  %r0 = mul i32 %i, 5
  %r = and i32 %r0, 255
  %g0 = mul i32 %i, 11
  %g1 = and i32 %g0, 255
  %g = shl i32 %g1, 8
  %b0 = mul i32 %i, 17
  %b1 = and i32 %b0, 255
  %b = shl i32 %b1, 16
  %rg = or i32 %r, %g
  %rgb = or i32 %rg, %b
  %rgba = or i32 %rgb, -2147483648
  %c = zext i32 %rgba to i64
  %x0 = mul i32 %i, 37
  %x1 = and i32 %x0, 511
  %x = shl i32 %x1, 4
  %y0 = mul i32 %i, 91
  %y1 = and i32 %y0, 511
  %y = shl i32 %y1, 20
  %xy = or i32 %x, %y
  %xy64 = zext i32 %xy to i64
  %z0 = mul i32 %i, 3
  %z = zext i32 %z0 to i64
  %zs = shl i64 %z, 32
  %xyz = or i64 %xy64, %zs
  store i64 %c, ptr %p, align 8
  %p1 = getelementptr inbounds i8, ptr %p, i32 8
  store i64 1065353216, ptr %p1, align 8
  %p2 = getelementptr inbounds i8, ptr %p, i32 16
  store i64 %xyz, ptr %p2, align 8
  %p3 = getelementptr inbounds i8, ptr %p, i32 24
  store i64 0, ptr %p3, align 8
  %p.next = getelementptr inbounds i8, ptr %p, i32 32
  %i.next = add nuw i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret void
}
