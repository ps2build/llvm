; RUN: llc -mtriple=mips64el-unknown-elf -mcpu=r5900 -target-abi=n32 -O2 < %s | FileCheck %s

; The R5900 has the integer movz and movn but no FPU conditional moves.

define i32 @smin(i32 %a, i32 %b) {
; CHECK-LABEL: smin:
; CHECK:         slt $3, $1, $2
; CHECK-NEXT:    jr $ra
; CHECK-NEXT:    movn $2, $1, $3
  %c = icmp slt i32 %a, %b
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
