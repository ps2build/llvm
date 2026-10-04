//=- MipsScheduleR5900.td - R5900 Scheduling Definitions -----*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Scheduling model for the R5900 (PlayStation 2 Emotion Engine core): in-order,
// two integer pipes, one load/store unit, one branch unit and one FPU.
//
// The numbers were measured on a console with ps2-latency-bench (COP0 Count,
// dependent chains for latency, independent groups for unit occupancy, and
// producer/consumer pairs for forwarding). Where the benchmark did not cover
// an operation the figure comes from the ps2dev GCC fork's 5900.md. Only the
// instructions the compiler selects are listed; the model is incomplete on
// purpose, and anything unlisted gets the default one-cycle latency.
//
//===----------------------------------------------------------------------===//

def MipsR5900Model : SchedMachineModel {
  int IssueWidth = 2;
  int MicroOpBufferSize = 0;

  int LoadLatency = 2;
  int MispredictPenalty = 1;

  int HighLatency = 37;
  list<Predicate> UnsupportedFeatures = [];

  let CompleteModel = 0;
  let PostRAScheduler = 1;
}

let SchedModel = MipsR5900Model in {

def R5900ALU0 : ProcResource<1>;
def R5900ALU1 : ProcResource<1>;
def R5900ALU : ProcResGroup<[R5900ALU0, R5900ALU1]>;
def R5900LS : ProcResource<1>;
def R5900BR : ProcResource<1>;
def R5900FPU : ProcResource<1>;

def R5900WriteALU : SchedWriteRes<[R5900ALU]>;
def R5900WriteALU0 : SchedWriteRes<[R5900ALU0]>;
def R5900WriteLS : SchedWriteRes<[R5900LS]> { let Latency = 2; }
def R5900WriteBR : SchedWriteRes<[R5900BR]>;

def R5900WriteFPLS : SchedWriteRes<[R5900FPU]> { let Latency = 3; }
def R5900WriteFP : SchedWriteRes<[R5900FPU]> { let Latency = 4; }
def R5900WriteFPDiv : SchedWriteRes<[R5900FPU]> {
  let Latency = 7;
  let ReleaseAtCycles = [7];
}
def R5900WriteFPRsqrt : SchedWriteRes<[R5900FPU]> {
  let Latency = 13;
  let ReleaseAtCycles = [13];
}
// Compare results are read by the core side (bc1t/bc1f); measured about 5.5
// cycles from c.cond.s to a taken bc1t, of which 2 are the taken branch.
def R5900WriteFPCmp : SchedWriteRes<[R5900FPU]> { let Latency = 6; }
def R5900WriteMTC1 : SchedWriteRes<[R5900FPU, R5900LS]> { let Latency = 3; }
def R5900WriteMFC1 : SchedWriteRes<[R5900FPU, R5900LS]> { let Latency = 2; }

def R5900WriteIMul : SchedWriteRes<[R5900ALU0]> {
  let Latency = 4;
  let ReleaseAtCycles = [2];
}
def R5900WriteIDiv : SchedWriteRes<[R5900ALU0]> {
  let Latency = 37;
  let ReleaseAtCycles = [37];
}

def : InstRW<[R5900WriteALU], (instregex
  "^(ADD|ADDi|ADDiu|ADDu|AND|ANDi|NOR|OR|ORi|XOR|XORi|SUB|SUBu|SLL|SLLV|SRA|"
  "SRAV|SRL|SRLV|SLT|SLTi|SLTiu|SLTu|LUi|DADDiu|DADDu|DSUBu|DSLL|DSLL32|"
  "DSLLV|DSRA|DSRA32|DSRAV|DSRL|DSRL32|DSRLV|SLL64_32|SLL64_64|SEB|SEH|"
  "MOVN_I_I|MOVZ_I_I|MOVN_I64_I|MOVZ_I64_I|NOP|COPY|LEA_ADDiu)$")>;

def : InstRW<[R5900WriteLS], (instregex
  "^(LB|LB64|LBu|LBu64|LD|LH|LH64|LHu|LHu64|LW|LW64|LWu|LQ|SB|SB64|SD|SH|SH64|"
  "SW|SW64|SQ)$")>;

def : InstRW<[R5900WriteFPLS], (instregex "^(LWC1|SWC1)$")>;

def : InstRW<[R5900WriteFP], (instregex
  "^(FADD_S|FSUB_S|FMUL_S|FABS_S|FNEG_S|FMOV_S|CVT_S_W|CVT_W_S|"
  "TRUNC_W_S|MAX_S_R5900|MIN_S_R5900)$")>;
def : InstRW<[R5900WriteFPDiv], (instregex "^(FDIV_S|FSQRT_S|FSQRT_S_R5900)$")>;
def : InstRW<[R5900WriteFPRsqrt], (instregex "^RSQRT_S_R5900$")>;
def : InstRW<[R5900WriteFPCmp], (instregex "^FCMP_S32$")>;
def : InstRW<[R5900WriteMTC1], (instregex "^MTC1$")>;
def : InstRW<[R5900WriteMFC1], (instregex "^MFC1$")>;

def : InstRW<[R5900WriteBR], (instregex
  "^(BEQ|BEQ64|BNE|BNE64|BGEZ|BGEZ64|BGTZ|BLEZ|BLTZ|J|JR|JAL|JALR|JALR64|"
  "BC1T|BC1F|RetRA|PseudoReturn|PseudoReturn64|PseudoIndirectBranch)$")>;

def : InstRW<[R5900WriteALU0], (instregex
  "^(MFHI|MFLO|MTHI|MTLO|PseudoMFHI|PseudoMFLO|PseudoMTLOHI)$")>;
def : InstRW<[R5900WriteIMul], (instregex
  "^(MULT|MULTu|MUL|PseudoMULT|PseudoMULTu)$")>;
def : InstRW<[R5900WriteIDiv], (instregex "^(DIV|DIVu|PseudoSDIV|PseudoUDIV)$")>;

}
