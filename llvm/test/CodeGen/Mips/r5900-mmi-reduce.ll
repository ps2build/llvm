; RUN: llc -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -O2 < %s | FileCheck %s
; RUN: opt -passes=loop-vectorize -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -S %s | FileCheck %s --check-prefix=IR

; Horizontal reduction, splat and constant-index extract stay in registers
; (pcpyud / dsrl / pcpyld) instead of round-tripping through the stack.

declare <8 x i16> @llvm.smax.v8i16(<8 x i16>, <8 x i16>)

; CHECK-LABEL: reduce_max:
; CHECK:       pcpyud
; CHECK:       pmaxh
; CHECK:       dsrl {{.*}}, 32
; CHECK:       pmaxh
; CHECK:       dsrl {{.*}}, 16
; CHECK:       pmaxh
; CHECK-NOT:   sq
define i16 @reduce_max(<8 x i16> %x) {
  %s1 = shufflevector <8 x i16> %x, <8 x i16> poison, <8 x i32> <i32 4, i32 5, i32 6, i32 7, i32 poison, i32 poison, i32 poison, i32 poison>
  %m1 = call <8 x i16> @llvm.smax.v8i16(<8 x i16> %x, <8 x i16> %s1)
  %s2 = shufflevector <8 x i16> %m1, <8 x i16> poison, <8 x i32> <i32 2, i32 3, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
  %m2 = call <8 x i16> @llvm.smax.v8i16(<8 x i16> %m1, <8 x i16> %s2)
  %s3 = shufflevector <8 x i16> %m2, <8 x i16> poison, <8 x i32> <i32 1, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
  %m3 = call <8 x i16> @llvm.smax.v8i16(<8 x i16> %m2, <8 x i16> %s3)
  %r = extractelement <8 x i16> %m3, i32 0
  ret i16 %r
}

; CHECK-LABEL: splat_h:
; CHECK:       dsll {{.*}}, 16
; CHECK:       dsll {{.*}}, 32
; CHECK:       pcpyld
; CHECK-NOT:   sh
define <8 x i16> @splat_h(i16 %a) {
  %i = insertelement <8 x i16> poison, i16 %a, i32 0
  %s = shufflevector <8 x i16> %i, <8 x i16> poison, <8 x i32> zeroinitializer
  ret <8 x i16> %s
}

; CHECK-LABEL: extract_hi:
; CHECK:       pcpyud
; CHECK:       dsrl {{.*}}, 16
define i16 @extract_hi(<8 x i16> %x) {
  %r = extractelement <8 x i16> %x, i32 5
  ret i16 %r
}

; The vectorized remainder loop is not worth its stack traffic: expect no
; vec.epilog blocks.
; IR-LABEL: @hmax(
; IR-NOT:   vec.epilog
define i16 @hmax(ptr %a, i32 %n) {
entry:
  %a0 = load i16, ptr %a
  br label %loop
loop:
  %i = phi i32 [ 1, %entry ], [ %i.next, %loop ]
  %m = phi i16 [ %a0, %entry ], [ %m.next, %loop ]
  %p = getelementptr i16, ptr %a, i32 %i
  %v = load i16, ptr %p
  %m.next = call i16 @llvm.smax.i16(i16 %m, i16 %v)
  %i.next = add nuw nsw i32 %i, 1
  %c = icmp eq i32 %i.next, %n
  br i1 %c, label %exit, label %loop
exit:
  ret i16 %m.next
}
declare i16 @llvm.smax.i16(i16, i16)
