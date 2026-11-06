; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -O2 < %s | FileCheck %s
; RUN: opt -passes=loop-vectorize -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -S %s | FileCheck %s --check-prefix=IR

; Zero extension interleaves with $zero.
; CHECK-LABEL: zext_b_h:
; CHECK: pextlb ${{[0-9]+}}, $zero, ${{[0-9]+}}
; CHECK: pextub ${{[0-9]+}}, $zero, ${{[0-9]+}}
define void @zext_b_h(ptr align 16 %s, ptr align 16 %d) {
  %v = load <16 x i8>, ptr %s, align 16
  %z = zext <16 x i8> %v to <16 x i16>
  store <16 x i16> %z, ptr %d, align 16
  ret void
}

; Sign extension interleaves with the register itself, then shifts.
; CHECK-LABEL: sext_h_w:
; CHECK: pextlh [[L:\$[0-9]+]], [[S:\$[0-9]+]], [[S]]
; CHECK: psraw {{.*}}, 16
; CHECK: pextuh {{.*}}, [[S]], [[S]]
; CHECK: psraw {{.*}}, 16
define void @sext_h_w(ptr align 16 %s, ptr align 16 %d) {
  %v = load <8 x i16>, ptr %s, align 16
  %z = sext <8 x i16> %v to <8 x i32>
  store <8 x i32> %z, ptr %d, align 16
  ret void
}

; Bytes to words extends twice.
; CHECK-LABEL: zext_b_w:
; CHECK-DAG: pextlb
; CHECK-DAG: pextlh
; CHECK-DAG: pextuh
; CHECK-DAG: pextub
define void @zext_b_w(ptr align 16 %s, ptr align 16 %d) {
  %v = load <16 x i8>, ptr %s, align 16
  %z = zext <16 x i8> %v to <16 x i32>
  store <16 x i32> %z, ptr %d, align 16
  ret void
}

; Truncation packs the even halfwords of two registers.
; CHECK-LABEL: trunc_w_h:
; CHECK: ppach
define void @trunc_w_h(ptr align 16 %s, ptr align 16 %d) {
  %v = load <8 x i32>, ptr %s, align 16
  %z = trunc <8 x i32> %v to <8 x i16>
  store <8 x i16> %z, ptr %d, align 16
  ret void
}

; CHECK-LABEL: trunc_h_b:
; CHECK: ppacb
define void @trunc_h_b(ptr align 16 %s, ptr align 16 %d) {
  %v = load <16 x i16>, ptr %s, align 16
  %z = trunc <16 x i16> %v to <16 x i8>
  store <16 x i8> %z, ptr %d, align 16
  ret void
}

; The vectorizer sizes the loop from the narrowest element, 16 bytes here.
; IR-LABEL: @bytes_to_halves(
; IR: zext <16 x i8>
define void @bytes_to_halves(ptr noalias %out, ptr noalias %in, i32 %n) {
entry:
  %c = icmp sgt i32 %n, 0
  br i1 %c, label %loop, label %exit
loop:
  %i = phi i32 [ 0, %entry ], [ %i1, %loop ]
  %pi = getelementptr inbounds i8, ptr %in, i32 %i
  %x = load i8, ptr %pi, align 1
  %z = zext i8 %x to i16
  %po = getelementptr inbounds i16, ptr %out, i32 %i
  store i16 %z, ptr %po, align 2
  %i1 = add nuw nsw i32 %i, 1
  %e = icmp eq i32 %i1, %n
  br i1 %e, label %exit, label %loop
exit:
  ret void
}
