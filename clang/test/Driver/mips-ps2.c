// The PS2 triple selects the R5900 and the n32 ABI without -mcpu or -mabi.

// RUN: %clang --target=mips64r5900el-ps2-elf -### -c %s 2>&1 | FileCheck %s
// CHECK: "-triple" "mips64r5900el-ps2-unknown-elf"
// CHECK-SAME: "-target-cpu" "r5900"
// CHECK-SAME: "-target-abi" "n32"

// RUN: %clang --target=mips64r5900el-ps2-elf -mabi=n32 -### -c %s 2>&1 | FileCheck %s

// RUN: %clang --target=mips64r5900el-ps2-elf -E -dM %s -o - | FileCheck %s --check-prefix=MACRO
// MACRO-DAG: #define _ABIN32 2
// MACRO-DAG: #define _MIPS_ARCH_R5900 1
// MACRO-DAG: #define __mips_n32 1
