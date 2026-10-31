; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -O2 < %s | FileCheck %s

target datalayout = "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S64"

; CHECK-LABEL: neg_i8:
; CHECK: pcgtb
define <16 x i8> @neg_i8(<16 x i8> %x, <16 x i8> %d) {
  %c = icmp slt <16 x i8> %x, zeroinitializer
  %s = select <16 x i1> %c, <16 x i8> %d, <16 x i8> %x
  ret <16 x i8> %s
}

; CHECK-LABEL: neg_i16:
; CHECK: pcgth
define <8 x i16> @neg_i16(<8 x i16> %x) {
  %c = icmp slt <8 x i16> %x, zeroinitializer
  %s = sext <8 x i1> %c to <8 x i16>
  ret <8 x i16> %s
}

; CHECK-LABEL: const_lhs_i32:
; CHECK: pcgtw
define <4 x i32> @const_lhs_i32(<4 x i32> %x) {
  %c = icmp sgt <4 x i32> <i32 5, i32 5, i32 5, i32 5>, %x
  %s = sext <4 x i1> %c to <4 x i32>
  ret <4 x i32> %s
}

; CHECK-LABEL: le_const_i32:
; CHECK: pcgtw
; CHECK: pnor
define <4 x i32> @le_const_i32(<4 x i32> %x) {
  %c = icmp sle <4 x i32> %x, <i32 7, i32 7, i32 7, i32 7>
  %s = sext <4 x i1> %c to <4 x i32>
  ret <4 x i32> %s
}

; CHECK-LABEL: ult_const_i16:
; CHECK: pcgth
define <8 x i16> @ult_const_i16(<8 x i16> %x) {
  %c = icmp ult <8 x i16> %x, <i16 9, i16 9, i16 9, i16 9, i16 9, i16 9, i16 9, i16 9>
  %s = sext <8 x i1> %c to <8 x i16>
  ret <8 x i16> %s
}
