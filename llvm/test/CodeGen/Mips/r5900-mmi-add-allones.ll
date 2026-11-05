; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -O2 < %s | FileCheck %s

target datalayout = "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S64"

; CHECK-LABEL: add_allones_i32:
; CHECK: pnor
; CHECK: paddw
define <4 x i32> @add_allones_i32(<4 x i32> %x) {
  %r = add <4 x i32> %x, splat (i32 -1)
  ret <4 x i32> %r
}
