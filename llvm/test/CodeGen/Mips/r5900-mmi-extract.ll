; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s

; CHECK-LABEL: extract_w2:
; CHECK:       lw $2, {{[0-9]+}}($sp)
define i32 @extract_w2(<4 x i32> %a) {
  %r = extractelement <4 x i32> %a, i32 2
  ret i32 %r
}

; CHECK-LABEL: extract_d1:
; CHECK:       move $2, $5
define i64 @extract_d1(<2 x i64> %a) {
  %r = extractelement <2 x i64> %a, i32 1
  ret i64 %r
}
