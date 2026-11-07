; RUN: llc -mtriple=mips64r5900el-ps2-elf -O2 < %s | FileCheck %s

; Saturating vector add/sub map onto the MMI PADDS*/PADDU*/PSUBS*/PSUBU*.

declare <16 x i8> @llvm.sadd.sat.v16i8(<16 x i8>, <16 x i8>)
declare <8 x i16> @llvm.sadd.sat.v8i16(<8 x i16>, <8 x i16>)
declare <4 x i32> @llvm.sadd.sat.v4i32(<4 x i32>, <4 x i32>)
declare <16 x i8> @llvm.uadd.sat.v16i8(<16 x i8>, <16 x i8>)
declare <8 x i16> @llvm.uadd.sat.v8i16(<8 x i16>, <8 x i16>)
declare <4 x i32> @llvm.uadd.sat.v4i32(<4 x i32>, <4 x i32>)
declare <16 x i8> @llvm.ssub.sat.v16i8(<16 x i8>, <16 x i8>)
declare <8 x i16> @llvm.ssub.sat.v8i16(<8 x i16>, <8 x i16>)
declare <4 x i32> @llvm.ssub.sat.v4i32(<4 x i32>, <4 x i32>)
declare <16 x i8> @llvm.usub.sat.v16i8(<16 x i8>, <16 x i8>)
declare <8 x i16> @llvm.usub.sat.v8i16(<8 x i16>, <8 x i16>)
declare <4 x i32> @llvm.usub.sat.v4i32(<4 x i32>, <4 x i32>)

; CHECK-LABEL: sadd_b:
; CHECK: paddsb
define <16 x i8> @sadd_b(<16 x i8> %x, <16 x i8> %y) {
  %r = call <16 x i8> @llvm.sadd.sat.v16i8(<16 x i8> %x, <16 x i8> %y)
  ret <16 x i8> %r
}
; CHECK-LABEL: sadd_h:
; CHECK: paddsh
define <8 x i16> @sadd_h(<8 x i16> %x, <8 x i16> %y) {
  %r = call <8 x i16> @llvm.sadd.sat.v8i16(<8 x i16> %x, <8 x i16> %y)
  ret <8 x i16> %r
}
; CHECK-LABEL: sadd_w:
; CHECK: paddsw
define <4 x i32> @sadd_w(<4 x i32> %x, <4 x i32> %y) {
  %r = call <4 x i32> @llvm.sadd.sat.v4i32(<4 x i32> %x, <4 x i32> %y)
  ret <4 x i32> %r
}
; CHECK-LABEL: uadd_b:
; CHECK: paddub
define <16 x i8> @uadd_b(<16 x i8> %x, <16 x i8> %y) {
  %r = call <16 x i8> @llvm.uadd.sat.v16i8(<16 x i8> %x, <16 x i8> %y)
  ret <16 x i8> %r
}
; CHECK-LABEL: uadd_h:
; CHECK: padduh
define <8 x i16> @uadd_h(<8 x i16> %x, <8 x i16> %y) {
  %r = call <8 x i16> @llvm.uadd.sat.v8i16(<8 x i16> %x, <8 x i16> %y)
  ret <8 x i16> %r
}
; CHECK-LABEL: uadd_w:
; CHECK: padduw
define <4 x i32> @uadd_w(<4 x i32> %x, <4 x i32> %y) {
  %r = call <4 x i32> @llvm.uadd.sat.v4i32(<4 x i32> %x, <4 x i32> %y)
  ret <4 x i32> %r
}
; CHECK-LABEL: ssub_b:
; CHECK: psubsb
define <16 x i8> @ssub_b(<16 x i8> %x, <16 x i8> %y) {
  %r = call <16 x i8> @llvm.ssub.sat.v16i8(<16 x i8> %x, <16 x i8> %y)
  ret <16 x i8> %r
}
; CHECK-LABEL: ssub_h:
; CHECK: psubsh
define <8 x i16> @ssub_h(<8 x i16> %x, <8 x i16> %y) {
  %r = call <8 x i16> @llvm.ssub.sat.v8i16(<8 x i16> %x, <8 x i16> %y)
  ret <8 x i16> %r
}
; CHECK-LABEL: ssub_w:
; CHECK: psubsw
define <4 x i32> @ssub_w(<4 x i32> %x, <4 x i32> %y) {
  %r = call <4 x i32> @llvm.ssub.sat.v4i32(<4 x i32> %x, <4 x i32> %y)
  ret <4 x i32> %r
}
; CHECK-LABEL: usub_b:
; CHECK: psubub
define <16 x i8> @usub_b(<16 x i8> %x, <16 x i8> %y) {
  %r = call <16 x i8> @llvm.usub.sat.v16i8(<16 x i8> %x, <16 x i8> %y)
  ret <16 x i8> %r
}
; CHECK-LABEL: usub_h:
; CHECK: psubuh
define <8 x i16> @usub_h(<8 x i16> %x, <8 x i16> %y) {
  %r = call <8 x i16> @llvm.usub.sat.v8i16(<8 x i16> %x, <8 x i16> %y)
  ret <8 x i16> %r
}
; CHECK-LABEL: usub_w:
; CHECK: psubuw
define <4 x i32> @usub_w(<4 x i32> %x, <4 x i32> %y) {
  %r = call <4 x i32> @llvm.usub.sat.v4i32(<4 x i32> %x, <4 x i32> %y)
  ret <4 x i32> %r
}
