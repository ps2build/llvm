; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 < %s | FileCheck %s
; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -filetype=obj < %s -o %t.o

declare <8 x i16> @llvm.smin.v8i16(<8 x i16>, <8 x i16>)
declare <4 x i32> @llvm.smax.v4i32(<4 x i32>, <4 x i32>)

; CHECK-LABEL: smax_w:
; CHECK: pmaxw
define <4 x i32> @smax_w(<4 x i32> %a, <4 x i32> %b) {
  %r = call <4 x i32> @llvm.smax.v4i32(<4 x i32> %a, <4 x i32> %b)
  ret <4 x i32> %r
}

; CHECK-LABEL: smin_h:
; CHECK: pminh
define <8 x i16> @smin_h(<8 x i16> %a, <8 x i16> %b) {
  %r = call <8 x i16> @llvm.smin.v8i16(<8 x i16> %a, <8 x i16> %b)
  ret <8 x i16> %r
}

; CHECK-LABEL: eq_w:
; CHECK: pceqw
define <4 x i32> @eq_w(<4 x i32> %a, <4 x i32> %b) {
  %c = icmp eq <4 x i32> %a, %b
  %r = sext <4 x i1> %c to <4 x i32>
  ret <4 x i32> %r
}

; CHECK-LABEL: ne_w:
; CHECK: pceqw
; CHECK: pnor
define <4 x i32> @ne_w(<4 x i32> %a, <4 x i32> %b) {
  %c = icmp ne <4 x i32> %a, %b
  %r = sext <4 x i1> %c to <4 x i32>
  ret <4 x i32> %r
}

; CHECK-LABEL: gt_b:
; CHECK: pcgtb
define <16 x i8> @gt_b(<16 x i8> %a, <16 x i8> %b) {
  %c = icmp sgt <16 x i8> %a, %b
  %r = sext <16 x i1> %c to <16 x i8>
  ret <16 x i8> %r
}

; CHECK-LABEL: ult_w:
; CHECK: psllw {{.*}}, 31
; CHECK: pcgtw
define <4 x i32> @ult_w(<4 x i32> %a, <4 x i32> %b) {
  %c = icmp ult <4 x i32> %a, %b
  %r = sext <4 x i1> %c to <4 x i32>
  ret <4 x i32> %r
}

; CHECK-LABEL: shl_h:
; CHECK: psllh {{.*}}, 3
define <8 x i16> @shl_h(<8 x i16> %a) {
  %r = shl <8 x i16> %a, <i16 3, i16 3, i16 3, i16 3, i16 3, i16 3, i16 3, i16 3>
  ret <8 x i16> %r
}

; CHECK-LABEL: sra_w:
; CHECK: psraw {{.*}}, 31
define <4 x i32> @sra_w(<4 x i32> %a) {
  %r = ashr <4 x i32> %a, <i32 31, i32 31, i32 31, i32 31>
  ret <4 x i32> %r
}

; CHECK-LABEL: srl_w:
; CHECK: psrlw {{.*}}, 1
define <4 x i32> @srl_w(<4 x i32> %a) {
  %r = lshr <4 x i32> %a, <i32 1, i32 1, i32 1, i32 1>
  ret <4 x i32> %r
}
