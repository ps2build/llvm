; RUN: llc -mtriple=mipsel-unknown-elf -mcpu=r3000a -O2 < %s | FileCheck %s --check-prefix=R3000A
; RUN: llc -mtriple=mipsel-unknown-elf -mcpu=mips1 -O2 < %s | FileCheck %s --check-prefix=MIPS1

; Selects with the same condition share one branch diamond on the R3000A.

define i64 @sel(i32 %c, i64 %a) {
; R3000A-LABEL: sel:
; R3000A-COUNT-1: b{{n?}}ez
; R3000A-NOT:     b{{n?}}ez
;
; MIPS1-LABEL: sel:
; MIPS1:         b{{n?}}ez
; MIPS1:         b{{n?}}ez
  %t = icmp eq i32 %c, 0
  %r = select i1 %t, i64 %a, i64 -1
  ret i64 %r
}
