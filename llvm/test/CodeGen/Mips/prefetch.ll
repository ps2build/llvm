; RUN: llc -mtriple=mips64el -mcpu=mips3 < %s | FileCheck %s --check-prefix=NONE
; RUN: llc -mtriple=mips64el -mcpu=mips4 < %s | FileCheck %s --check-prefix=NONE
; RUN: llc -mtriple=mipsel -mcpu=mips32 < %s | FileCheck %s --check-prefix=NONE
; RUN: llc -mtriple=mips64el -mcpu=r5900 < %s | FileCheck %s --check-prefix=R5900
; RUN: llc -mtriple=mipsel -mcpu=mips32r6 < %s | FileCheck %s --check-prefix=NONE
; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -mattr=+micromips < %s | FileCheck %s --check-prefix=NONE

declare void @llvm.prefetch.p0(ptr, i32, i32, i32)

; R5900-LABEL: prefetch_data:
; R5900-COUNT-8: pref 0, {{[0-9]+}}($4)
; NONE-LABEL:  prefetch_data:
; NONE-NOT: {{[[:space:]]}}pref {{[0-9]}}
define void @prefetch_data(ptr %p) {
  %p1 = getelementptr i8, ptr %p, i32 4
  %p2 = getelementptr i8, ptr %p, i32 8
  %p3 = getelementptr i8, ptr %p, i32 12
  %p4 = getelementptr i8, ptr %p, i32 16
  %p5 = getelementptr i8, ptr %p, i32 20
  %p6 = getelementptr i8, ptr %p, i32 24
  %p7 = getelementptr i8, ptr %p, i32 28
  call void @llvm.prefetch.p0(ptr %p, i32 0, i32 0, i32 1)
  call void @llvm.prefetch.p0(ptr %p1, i32 0, i32 1, i32 1)
  call void @llvm.prefetch.p0(ptr %p2, i32 0, i32 2, i32 1)
  call void @llvm.prefetch.p0(ptr %p3, i32 0, i32 3, i32 1)
  call void @llvm.prefetch.p0(ptr %p4, i32 1, i32 0, i32 1)
  call void @llvm.prefetch.p0(ptr %p5, i32 1, i32 1, i32 1)
  call void @llvm.prefetch.p0(ptr %p6, i32 1, i32 2, i32 1)
  call void @llvm.prefetch.p0(ptr %p7, i32 1, i32 3, i32 1)
  ret void
}

; R5900-LABEL: prefetch_instruction:
; R5900-NOT: {{[[:space:]]}}pref {{[0-9]}}
define void @prefetch_instruction(ptr %p) {
  call void @llvm.prefetch.p0(ptr %p, i32 0, i32 3, i32 0)
  ret void
}
