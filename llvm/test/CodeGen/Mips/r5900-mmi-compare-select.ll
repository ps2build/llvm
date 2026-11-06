; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s

; CHECK-LABEL: smax_w:
; CHECK:       pmaxw
define <4 x i32> @smax_w(<4 x i32> %a, <4 x i32> %b) {
  %c = icmp sgt <4 x i32> %a, %b
  %r = select <4 x i1> %c, <4 x i32> %a, <4 x i32> %b
  ret <4 x i32> %r
}

; CHECK-LABEL: smin_h:
; CHECK:       pminh
define <8 x i16> @smin_h(<8 x i16> %a, <8 x i16> %b) {
  %c = icmp slt <8 x i16> %a, %b
  %r = select <8 x i1> %c, <8 x i16> %a, <8 x i16> %b
  ret <8 x i16> %r
}

; CHECK-LABEL: lt_mask_h:
; CHECK:       pcgth
define <8 x i16> @lt_mask_h(<8 x i16> %a, <8 x i16> %b) {
  %c = icmp slt <8 x i16> %a, %b
  %r = sext <8 x i1> %c to <8 x i16>
  ret <8 x i16> %r
}

; CHECK-LABEL: eq_mask_b:
; CHECK:       pceqb
define <16 x i8> @eq_mask_b(<16 x i8> %a, <16 x i8> %b) {
  %c = icmp eq <16 x i8> %a, %b
  %r = sext <16 x i1> %c to <16 x i8>
  ret <16 x i8> %r
}
