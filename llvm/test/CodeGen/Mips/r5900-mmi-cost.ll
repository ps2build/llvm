; RUN: opt -passes='print<cost-model>' -cost-kind=throughput -disable-output -mtriple=mips64r5900el-ps2-elf %s 2>&1 | FileCheck %s
; RUN: opt -passes=loop-vectorize -mtriple=mips64r5900el-ps2-elf -S %s | FileCheck %s --check-prefix=VEC

; CHECK-LABEL: 'ops'
; CHECK: cost of 1 for instruction: %add = add <4 x i32>
; CHECK: cost of {{[0-9][0-9]+}} for instruction: %mul = mul <4 x i32>
; CHECK: cost of {{[0-9][0-9]+}} for instruction: %shl = shl <4 x i32> %a, %b
define void @ops(<4 x i32> %a, <4 x i32> %b) {
  %add = add <4 x i32> %a, %b
  %mul = mul <4 x i32> %a, %b
  %shl = shl <4 x i32> %a, %b
  ret void
}

; Multiplies are scalarized through the stack, so the loop stays scalar.
; VEC-LABEL: @mul_arrays(
; VEC-NOT: <4 x i32>
define void @mul_arrays(ptr noalias align 16 %a, ptr noalias align 16 %b, ptr noalias align 16 %c, i32 %n) {
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
  %z = mul i32 %x, %y
  store i32 %z, ptr %pc, align 16
  %i.next = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
