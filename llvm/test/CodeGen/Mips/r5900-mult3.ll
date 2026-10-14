; RUN: llc -mtriple=mips64el-unknown-none -mcpu=r5900 < %s | FileCheck %s

; A 32-bit multiply selects the R5900 three-operand mult without a mflo.
define i32 @mul32(i32 %a, i32 %b) {
; CHECK-LABEL: mul32:
; CHECK:       mult ${{.*}}, ${{.*}}, ${{.*}}
; CHECK-NOT:   mflo
  %r = mul i32 %a, %b
  ret i32 %r
}
