; REQUIRES: mips
;; Test that bitcode for the MIPS n32 ABI links as ELF32 with EF_MIPS_ABI2,
;; alone, against the n32 emulation, and together with an n32 object file.

; RUN: split-file %s %t
; RUN: llvm-as %t/n32.ll -o %t/n32.o
; RUN: llvm-mc -filetype=obj -triple=mips64el-unknown-linux-gnuabin32 %t/f.s -o %t/f.o

; RUN: ld.lld %t/n32.o %t/f.o -o %t/out
; RUN: llvm-readobj -h %t/out | FileCheck %s
; RUN: ld.lld -m elf32ltsmipn32 %t/n32.o %t/f.o -o %t/out-m
; RUN: llvm-readobj -h %t/out-m | FileCheck %s
; RUN: ld.lld %t/f.o %t/n32.o -o %t/out-rev
; RUN: llvm-readobj -h %t/out-rev | FileCheck %s

; CHECK:      Class: 32-bit
; CHECK:      DataEncoding: LittleEndian
; CHECK:      Machine: EM_MIPS
; CHECK:      Flags [
; CHECK:        EF_MIPS_ABI2

;--- n32.ll
target datalayout = "e-m:e-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S128"
target triple = "mips64el-unknown-linux-gnuabin32"

declare void @f()

define void @__start() {
  call void @f()
  ret void
}

;--- f.s
  .globl f
f:
  jr $ra
  nop
