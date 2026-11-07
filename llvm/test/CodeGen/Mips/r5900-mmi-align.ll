; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' -S %s | FileCheck %s --check-prefix=IR
; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' %s -o - | llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -o - | FileCheck %s --check-prefix=ASM
; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' -mips-mmi-align-disable -S %s | FileCheck %s --check-prefix=OFF

target datalayout = "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S64"

; Pointers that are not known aligned: the vector loop is guarded.
; IR-LABEL: @add(
; IR: mmi.align.check:
; IR: and i32 %{{.*}}, 15
; IR: br i1 %{{.*}}, label %{{(scalar.ph|vec.epilog.ph)}}, label %vector.ph
; IR: load <4 x i32>, ptr %{{.*}}, align 16
; IR: store <4 x i32> %{{.*}}, ptr %{{.*}}, align 16
; OFF-LABEL: @add(
; OFF-NOT: mmi.align.check
; ASM-LABEL: add:
; ASM: lq
; ASM: lq
; ASM: paddw
; ASM: sq
define void @add(ptr noalias %d, ptr noalias %a, ptr noalias %b, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %pa = getelementptr inbounds i32, ptr %a, i32 %i
  %pb = getelementptr inbounds i32, ptr %b, i32 %i
  %pd = getelementptr inbounds i32, ptr %d, i32 %i
  %x = load i32, ptr %pa, align 4
  %y = load i32, ptr %pb, align 4
  %s = add i32 %x, %y
  store i32 %s, ptr %pd, align 4
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  ret void
}

; The offset input is checked at its own start address, and the reduction
; value reaches the scalar loop from the new block. The offset is not a constant here.
; IR-LABEL: @sum_off(
; IR: mmi.align.check:
; IR: getelementptr
; IR: ptrtoint
; IR: %bc.merge.rdx = phi i32 [ %{{.*}}, %vec.epilog.iter.check ], [ 0, %{{.*}} ], [ 0, %mmi.align.check ]
define i32 @sum_off(ptr noalias %a, i32 %k, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %acc = phi i32 [0, %entry], [%acc1, %loop]
  %j = add nuw nsw i32 %i, %k
  %pa = getelementptr inbounds i32, ptr %a, i32 %j
  %x = load i32, ptr %pa, align 4
  %acc1 = add i32 %acc, %x
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  %r = phi i32 [0, %entry], [%acc1, %loop]
  ret i32 %r
}

; An access that is already 16-byte aligned needs no check.
; IR-LABEL: @already(
; IR-NOT: mmi.align.check
define void @already(ptr noalias align 16 %d, ptr noalias align 16 %a, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %pa = getelementptr inbounds i32, ptr %a, i32 %i
  %pd = getelementptr inbounds i32, ptr %d, i32 %i
  %x = load i32, ptr %pa, align 16
  %s = add i32 %x, 1
  store i32 %s, ptr %pd, align 16
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  ret void
}

; a[i] and a[i + 1] cannot both be aligned: only a[i] is checked and marked,
; a[i + 1] stays a 4-byte aligned access for ldl/ldr.
; IR-LABEL: @stencil(
; IR: mmi.align.check:
; IR: and i32 %{{.*}}, 15
; IR: br i1 %{{.*}}, label %{{(scalar.ph|vec.epilog.ph)}}, label %vector.ph
; IR: load <4 x i32>, ptr %{{.*}}, align 16
; IR: load <4 x i32>, ptr %{{.*}}, align 4
define void @stencil(ptr noalias %d, ptr noalias %a, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %j = add nuw nsw i32 %i, 1
  %pa = getelementptr inbounds i32, ptr %a, i32 %i
  %pb = getelementptr inbounds i32, ptr %a, i32 %j
  %pd = getelementptr inbounds i32, ptr %d, i32 %i
  %x = load i32, ptr %pa, align 4
  %y = load i32, ptr %pb, align 4
  %s = add i32 %x, %y
  store i32 %s, ptr %pd, align 4
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  ret void
}

; A constant offset from the base is left to ldl/ldr: a start that is aligned
; only when the base is not would never pass the check.
; IR-LABEL: @const_off(
; IR-NOT: mmi.align.check
define i32 @const_off(ptr noalias %a, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %acc = phi i32 [0, %entry], [%acc1, %loop]
  %j = add nuw nsw i32 %i, 1
  %pa = getelementptr inbounds i32, ptr %a, i32 %j
  %x = load i32, ptr %pa, align 4
  %acc1 = add i32 %acc, %x
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  %r = phi i32 [0, %entry], [%acc1, %loop]
  ret i32 %r
}
