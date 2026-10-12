; A negative .fill count in inline assembly is diagnosed. The warning used to go through
; the assembler's source manager directly, which does not exist when the input is not an
; assembly file, and crashed.
; RUN: llc -mtriple=mipsel-unknown-linux-gnu -filetype=obj -o /dev/null %s 2>&1 | FileCheck %s

module asm ".fill -1, 1, 0"

; CHECK: warning: '.fill' directive with negative repeat count has no effect
