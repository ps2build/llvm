; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O2 < %s | FileCheck %s

; The R5900 has the integer movz and movn but no FPU conditional moves.

define i32 @sel32(i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: sel32:
; CHECK:         slt
; CHECK:         movn
  %x = icmp slt i32 %a, %b
  %r = select i1 %x, i32 %c, i32 %b
  ret i32 %r
}

; Scalar signed min/max use the MMI pminw/pmaxw.
define i32 @smin(i32 %a, i32 %b) {
; CHECK-LABEL: smin:
; CHECK:         pminw
  %c = icmp slt i32 %a, %b
  %r = select i1 %c, i32 %a, i32 %b
  ret i32 %r
}

define i32 @smax(i32 %a, i32 %b) {
; CHECK-LABEL: smax:
; CHECK:         pmaxw
  %c = icmp sgt i32 %a, %b
  %r = select i1 %c, i32 %a, i32 %b
  ret i32 %r
}

define i64 @sel64(i64 %a, i64 %b, i64 %x) {
; CHECK-LABEL: sel64:
; CHECK:         movz $5, $4, $6
  %c = icmp eq i64 %x, 0
  %r = select i1 %c, i64 %a, i64 %b
  ret i64 %r
}

define float @fsel(i32 %x, float %a, float %b) {
; CHECK-LABEL: fsel:
; CHECK-NOT:     movn.s
; CHECK-NOT:     movz.s
; CHECK:         bnez
  %c = icmp ne i32 %x, 0
  %r = select i1 %c, float %a, float %b
  ret float %r
}

define i32 @fcmp_isel(float %x, float %y, i32 %a, i32 %b) {
; CHECK-LABEL: fcmp_isel:
; CHECK-NOT:     movt
; CHECK-NOT:     movf
; CHECK:         c.olt.s $f12, $f13
; CHECK:         bc1t
  %c = fcmp olt float %x, %y
  %r = select i1 %c, i32 %a, i32 %b
  ret i32 %r
}
