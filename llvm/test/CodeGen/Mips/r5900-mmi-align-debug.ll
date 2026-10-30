; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' -S %s | FileCheck %s --check-prefix=IR
; RUN: opt -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -passes='loop-vectorize,mips-mmi-align,verify' %s -o - | llc -O2 -mtriple=mips64r5900el-ps2-elf -mcpu=r5900 -o - | FileCheck %s --check-prefix=ASM

target datalayout = "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32:64-S64"

; IR-LABEL: @add(
; IR: mmi.align.check:
; IR: br i1 %{{.*}}, label %scalar.ph, label %vector.ph
; ASM-LABEL: add:
; ASM: lq
define void @add(ptr noalias %d, ptr noalias %a, ptr noalias %b, i32 %n) !dbg !6 {
entry:
  %c = icmp sgt i32 %n, 0, !dbg !10
  br i1 %c, label %loop, label %exit, !dbg !10
loop:
  %i = phi i32 [0, %entry], [%i1, %loop]
  %pa = getelementptr inbounds i32, ptr %a, i32 %i, !dbg !11
  %pb = getelementptr inbounds i32, ptr %b, i32 %i, !dbg !11
  %pd = getelementptr inbounds i32, ptr %d, i32 %i, !dbg !11
  %x = load i32, ptr %pa, align 4, !dbg !11
  %y = load i32, ptr %pb, align 4, !dbg !11
  %s = add i32 %x, %y, !dbg !11
    #dbg_value(i32 %s, !9, !DIExpression(), !11)
  store i32 %s, ptr %pd, align 4, !dbg !11
  %i1 = add nuw nsw i32 %i, 1, !dbg !11
  %e = icmp eq i32 %i1, %n, !dbg !11
  br i1 %e, label %exit, label %loop, !dbg !11, !llvm.loop !12
exit:
  ret void, !dbg !10
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "add.c", directory: "/")
!3 = !{i32 2, !"Dwarf Version", i32 2}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!6 = distinct !DISubprogram(name: "add", scope: !1, file: !1, line: 1, type: !7, scopeLine: 1, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !8)
!7 = !DISubroutineType(types: !8)
!8 = !{}
!9 = !DILocalVariable(name: "s", scope: !6, file: !1, line: 3, type: !15)
!10 = !DILocation(line: 1, scope: !6)
!11 = !DILocation(line: 3, scope: !6)
!12 = distinct !{!12, !13}
!13 = !{!"llvm.loop.mustprogress"}
!15 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
