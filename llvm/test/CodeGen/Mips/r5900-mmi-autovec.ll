; RUN: opt -passes=loop-vectorize -mtriple=mips64r5900el-ps2-elf -S %s | FileCheck %s --check-prefix=IR
; RUN: opt -passes=loop-vectorize -mtriple=mips64r5900el-ps2-elf -S %s | llc -mtriple=mips64r5900el-ps2-elf -O2 | FileCheck %s --check-prefix=ASM

; IR-LABEL: @add_arrays(
; IR: vector.body:
; IR: add <4 x i32>
; ASM-LABEL: add_arrays:
; ASM: lq
; ASM: lq
; ASM: paddw
; ASM: sq
define void @add_arrays(ptr noalias align 16 %a, ptr noalias align 16 %b, ptr noalias align 16 %c, i32 %n) {
entry:
  %cmp = icmp sgt i32 %n, 0
  br i1 %cmp, label %loop, label %exit
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %pa = getelementptr inbounds i32, ptr %a, i32 %i
  %pb = getelementptr inbounds i32, ptr %b, i32 %i
  %pc = getelementptr inbounds i32, ptr %c, i32 %i
  %x = load i32, ptr %pa, align 16
  %y = load i32, ptr %pb, align 16
  %z = add i32 %x, %y
  store i32 %z, ptr %pc, align 16
  %i.next = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; Accesses below element alignment cost more than the scalar loop on hardware.
; IR-LABEL: @add_arrays_unaligned(
; IR-NOT: <4 x i32>
define void @add_arrays_unaligned(ptr noalias %a, ptr noalias %b, ptr noalias %c, i32 %n) {
entry:
  %cmp = icmp sgt i32 %n, 0
  br i1 %cmp, label %loop, label %exit
loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %pa = getelementptr inbounds i32, ptr %a, i32 %i
  %pb = getelementptr inbounds i32, ptr %b, i32 %i
  %pc = getelementptr inbounds i32, ptr %c, i32 %i
  %x = load i32, ptr %pa, align 1
  %y = load i32, ptr %pb, align 1
  %z = add i32 %x, %y
  store i32 %z, ptr %pc, align 1
  %i.next = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
