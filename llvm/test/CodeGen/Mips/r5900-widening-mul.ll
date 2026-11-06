; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s
; RUN: llc -mtriple=mips64el -mcpu=mips64 < %s | FileCheck %s --check-prefix=MIPS64

; MIPS64-NOT: pmultw
; MIPS64-NOT: pmultuw

define i64 @smul_wide(i32 %a, i32 %b) {
; CHECK-LABEL: smul_wide:
; CHECK:         pmultw ${{[0-9]+}}, ${{[0-9]+}}, ${{[0-9]+}}
  %x = sext i32 %a to i64
  %y = sext i32 %b to i64
  %m = mul i64 %x, %y
  ret i64 %m
}

define i64 @umul_wide(i32 %a, i32 %b) {
; CHECK-LABEL: umul_wide:
; CHECK:         pmultuw ${{[0-9]+}}, ${{[0-9]+}}, ${{[0-9]+}}
  %x = zext i32 %a to i64
  %y = zext i32 %b to i64
  %m = mul i64 %x, %y
  ret i64 %m
}

define i64 @mul_full(i64 %a, i64 %b) {
; CHECK-LABEL: mul_full:
; CHECK-NOT:     pmultw
; CHECK-NOT:     pmultuw
  %m = mul i64 %a, %b
  ret i64 %m
}
