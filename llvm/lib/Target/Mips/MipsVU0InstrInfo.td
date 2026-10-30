//===-- MipsVU0InstrInfo.td - R5900 VU0 macro-mode (VUX) -*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// VU0 macro-mode (COP2) instructions for the R5900 (PS2 Emotion Engine).
// Asm/inline-asm only: none of this is reachable from C codegen (no
// patterns, no legalizer/calling-convention wiring for VU0VF/VU0VI/VU0ACC).
//
// Bit layout and operand encoding transcribed from the authoritative
// reference already in this workspace: the R5900-forked binutils'
// opcodes/mips-opc.c (opcode/mask values) and its
// include/opcode/mips.h operand-letter documentation ("+5" FD at bit 6,
// "+6" FS at bit 11, "+7" FT at bit 16, "+K" 4-bit channel mask at bit 21,
// dest-field mask bit order x=8,y=4,z=2,w=1 per tc-mips.c's
// mips_parse_vu0_channels). Asm *syntax* is not required to match GAS
// (confirmed with the user) - each field-combination is its own literal
// TableGen mnemonic (vadd.xyzw, vadd.xyz, ...) instead of replicating GAS's
// mnemonic-suffix-stripping parser, and accumulator-family operand order is
// normalized to ($fs, $ft) here even where the real assembler is
// inconsistent about it (vadda lists them as +7,+6; vsuba/vmula as +6,+7) -
// this only affects what a user types, not the encoded bit positions.
//
//===----------------------------------------------------------------------===//

// FD-writing 3-operand arithmetic (vadd/vsub/vmul): op=COP2, CO=1,
// mask@24-21, FT@20-16, FS@15-11, FD@10-6, funct@5-0.
class VU0_3R_FM<bits<6> funct, bits<4> mask> : StdArch {
  bits<5> fd;
  bits<5> fs;
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = ft;
  let Inst{15-11} = fs;
  let Inst{10-6}  = fd;
  let Inst{5-0}   = funct;
}

// ACC-writing 2-operand arithmetic (vadda/vsuba/vmula): same shape, but
// there's no FD register (result goes to the implicit $ACC) - bits 10-0
// become an 11-bit extended funct instead of funct+FD.
class VU0_ACC_FM<bits<11> funct, bits<4> mask> : StdArch {
  bits<5> fs;
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = ft;
  let Inst{15-11} = fs;
  let Inst{10-0}  = funct;
}

class VU0_3R_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$fd), (ins VU0VFOpnd:$fs, VU0VFOpnd:$ft),
         !strconcat(opstr, "\t$fd, $fs, $ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  // Asm/inline-asm only - no C codegen path exists to schedule for.
  let hasNoSchedulingInfo = 1;
}

class VU0_ACC_DESC<string opstr> :
  InstSE<(outs), (ins VU0ACCOpnd:$acc, VU0VFOpnd:$fs, VU0VFOpnd:$ft),
         !strconcat(opstr, "\t$acc, $fs, $ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  // $acc is asm-only decoration (see VU0ACCOpnd) - the real destination
  // is always the same implicit ACC register, declared here too so
  // codegen/scheduling sees the write.
  let Defs = [ACC];
}

// One literal instruction per non-empty subset of {x,y,z,w} - mechanical
// once the (suffix, mask) list is fixed (mask bit order: x=8,y=4,z=2,w=1).
multiclass VU0_3R_Arith<string opstr, bits<6> funct> {
  def _x    : VU0_3R_DESC<opstr#".x">,    VU0_3R_FM<funct, 0b1000>;
  def _y    : VU0_3R_DESC<opstr#".y">,    VU0_3R_FM<funct, 0b0100>;
  def _z    : VU0_3R_DESC<opstr#".z">,    VU0_3R_FM<funct, 0b0010>;
  def _w    : VU0_3R_DESC<opstr#".w">,    VU0_3R_FM<funct, 0b0001>;
  def _xy   : VU0_3R_DESC<opstr#".xy">,   VU0_3R_FM<funct, 0b1100>;
  def _xz   : VU0_3R_DESC<opstr#".xz">,   VU0_3R_FM<funct, 0b1010>;
  def _xw   : VU0_3R_DESC<opstr#".xw">,   VU0_3R_FM<funct, 0b1001>;
  def _yz   : VU0_3R_DESC<opstr#".yz">,   VU0_3R_FM<funct, 0b0110>;
  def _yw   : VU0_3R_DESC<opstr#".yw">,   VU0_3R_FM<funct, 0b0101>;
  def _zw   : VU0_3R_DESC<opstr#".zw">,   VU0_3R_FM<funct, 0b0011>;
  def _xyz  : VU0_3R_DESC<opstr#".xyz">,  VU0_3R_FM<funct, 0b1110>;
  def _xyw  : VU0_3R_DESC<opstr#".xyw">,  VU0_3R_FM<funct, 0b1101>;
  def _xzw  : VU0_3R_DESC<opstr#".xzw">,  VU0_3R_FM<funct, 0b1011>;
  def _yzw  : VU0_3R_DESC<opstr#".yzw">,  VU0_3R_FM<funct, 0b0111>;
  def _xyzw : VU0_3R_DESC<opstr#".xyzw">, VU0_3R_FM<funct, 0b1111>;
  // See VU0_ACC_Arith's bare-mnemonic alias below - same shorthand. A
  // real alternate spelling of the identical _xyzw encoding needs to be
  // an InstAlias, not a second Instruction def - two Instructions with
  // the same Inst bits is a disassembler-table conflict, since InstAlias
  // never gets its own disassembler-table entry (it just names another
  // way to parse/print an existing real instruction).
  def : MipsInstAlias<!strconcat(opstr, " $fd, $fs, $ft"),
          (!cast<Instruction>(NAME#"_xyzw") VU0VFOpnd:$fd, VU0VFOpnd:$fs,
                                             VU0VFOpnd:$ft), 1>;
}

multiclass VU0_ACC_Arith<string opstr, bits<11> funct> {
  def _x    : VU0_ACC_DESC<opstr#".x">,    VU0_ACC_FM<funct, 0b1000>;
  def _y    : VU0_ACC_DESC<opstr#".y">,    VU0_ACC_FM<funct, 0b0100>;
  def _z    : VU0_ACC_DESC<opstr#".z">,    VU0_ACC_FM<funct, 0b0010>;
  def _w    : VU0_ACC_DESC<opstr#".w">,    VU0_ACC_FM<funct, 0b0001>;
  def _xy   : VU0_ACC_DESC<opstr#".xy">,   VU0_ACC_FM<funct, 0b1100>;
  def _xz   : VU0_ACC_DESC<opstr#".xz">,   VU0_ACC_FM<funct, 0b1010>;
  def _xw   : VU0_ACC_DESC<opstr#".xw">,   VU0_ACC_FM<funct, 0b1001>;
  def _yz   : VU0_ACC_DESC<opstr#".yz">,   VU0_ACC_FM<funct, 0b0110>;
  def _yw   : VU0_ACC_DESC<opstr#".yw">,   VU0_ACC_FM<funct, 0b0101>;
  def _zw   : VU0_ACC_DESC<opstr#".zw">,   VU0_ACC_FM<funct, 0b0011>;
  def _xyz  : VU0_ACC_DESC<opstr#".xyz">,  VU0_ACC_FM<funct, 0b1110>;
  def _xyw  : VU0_ACC_DESC<opstr#".xyw">,  VU0_ACC_FM<funct, 0b1101>;
  def _xzw  : VU0_ACC_DESC<opstr#".xzw">,  VU0_ACC_FM<funct, 0b1011>;
  def _yzw  : VU0_ACC_DESC<opstr#".yzw">,  VU0_ACC_FM<funct, 0b0111>;
  def _xyzw : VU0_ACC_DESC<opstr#".xyzw">, VU0_ACC_FM<funct, 0b1111>;
  // Real GNU as also accepts the bare mnemonic (no dot) as shorthand for
  // the full-xyzw destination field mask - found while porting sdk-core's
  // math3d.c ("vmulaw $ACC, $vf4, $vf0", no ".xyzw"). An InstAlias, not a
  // second Instruction def - see VU0_3R_Arith's own alias above for why.
  def : MipsInstAlias<!strconcat(opstr, " $acc, $fs, $ft"),
          (!cast<Instruction>(NAME#"_xyzw") VU0ACCOpnd:$acc, VU0VFOpnd:$fs,
                                             VU0VFOpnd:$ft), 1>;
}

// opcodes/mips-opc.c: vadd=0x4a000028, vsub=0x4a00002c, vmul=0x4a00002a
// (funct = low 6 bits, template fields zeroed).
defm VADD : VU0_3R_Arith<"vadd", 0x28>;
defm VSUB : VU0_3R_Arith<"vsub", 0x2c>;
defm VMUL : VU0_3R_Arith<"vmul", 0x2a>;

// opcodes/mips-opc.c: vadda=0x4a0002bc, vsuba=0x4a0002fc, vmula=0x4a0002be
// (funct = low 11 bits).
defm VADDA : VU0_ACC_Arith<"vadda", 0x2bc>;
defm VSUBA : VU0_ACC_Arith<"vsuba", 0x2fc>;
defm VMULA : VU0_ACC_Arith<"vmula", 0x2be>;

// VU0->EE and EE->VU0 128-bit transfer. Same op/mfmt-slot shape as
// DMFC2/DMTC2 (MipsInstrInfo.td's MFC3OP/MTC3OP + MipsInstrFormats.td's
// MFC3OP_FM<0x12, mfmt, 0>) - R5900 repurposes the DMFC2/DMTC2 mfmt slots
// (1 and 5) for the 128-bit qmfc2/qmtc2 transfer instead, per
// opcodes/mips-opc.c (qmfc2=0x48200000, qmtc2=0x48a00000, both mfmt @ bits
// 25-21 = 1 / 5). Real syntax ("t,+6" in mips-opc.c) is 2-operand only,
// no $sel at all - MFC3OP is the wrong class here (it's a 3-operand
// class built for COP0's select-capable MFC0 form, same mismatch CFC2/
// CTC2 hit elsewhere in this file); own 2-operand class instead.
class QMFC2OP<string asmstr, bits<5> mfmt, dag outs, dag ins> :
  InstSE<outs, ins, !strconcat(asmstr, "\t$rt, $rd"), [], FrmFR>, StdArch {
  bits<5> rt;
  bits<5> rd;
  let Inst{31-26} = 0x12;
  let Inst{25-21} = mfmt;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-0}  = 0;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1 in {
def QMFC2 : QMFC2OP<"qmfc2", 1, (outs GPR64Opnd:$rt), (ins VU0VFOpnd:$rd)>;
def QMTC2 : QMFC2OP<"qmtc2", 5, (outs), (ins GPR64Opnd:$rt, VU0VFOpnd:$rd)>;
}

// opcodes/mips-opc.c: vnop=0x4a0002ff, mask=0xffffffff (fully fixed, no
// operand fields at all).
let Predicates = [HasVU0], hasNoSchedulingInfo = 1 in
def VNOP : InstSE<(outs), (ins), "vnop", [], FrmOther>, StdArch {
  let Inst = 0x4a0002ff;
}

// vwaitq: stalls until $Q is ready - the real-hardware answer to the
// vnop-padding this file used earlier to dodge the EFU pipeline latency
// after vdiv/vsqrt/vrsqrt (opcodes/mips-opc.c: vwaitq=0x4a0003bf,
// mask=0xffffffff, fully fixed, no operand fields, same shape as vnop).
let Predicates = [HasVU0], hasNoSchedulingInfo = 1 in
def VWAITQ : InstSE<(outs), (ins), "vwaitq", [], FrmOther>, StdArch {
  let Inst = 0x4a0003bf;
}

// 128-bit memory<->VF0 load/store. opcodes/mips-opc.c: lqc2=0xd8000000
// (reuses the standard LDC2 major opcode, 0x36), sqc2=0xf8000000 (reuses
// SDC2's, 0x3e) - same repurposing pattern as QMFC2/QMTC2 reusing
// DMFC2/DMTC2's mfmt slots. Same base+offset shape as plain LW/SW
// (MipsInstrFormats.td's LW_FM/base+offset "mem" operand), just with the
// rt-position register field repurposed as a VF register number.
class VU0_LQC2_FM : StdArch {
  bits<5> vf;
  bits<21> addr;

  bits<32> Inst;

  let Inst{31-26} = 0x36;
  let Inst{25-21} = addr{20-16};
  let Inst{20-16} = vf;
  let Inst{15-0}  = addr{15-0};
}

class VU0_SQC2_FM : StdArch {
  bits<5> vf;
  bits<21> addr;

  bits<32> Inst;

  let Inst{31-26} = 0x3e;
  let Inst{25-21} = addr{20-16};
  let Inst{20-16} = vf;
  let Inst{15-0}  = addr{15-0};
}

// LQC2/SQC2 reuse LDC2/SDC2's exact opcode (see comment above) - LDC2/SDC2
// themselves are unconditional (no predicate gating), so the disassembler
// table generator sees a genuine same-encoding conflict between them and
// ours in the default "Mips" decode table. The R5900 table is tried before
// it, so these win on the EE.
let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "R5900" in {
def LQC2 : InstSE<(outs VU0VFOpnd:$vf), (ins mem:$addr), "lqc2\t$vf, $addr",
                  [], FrmFI>, VU0_LQC2_FM {
  let DecoderMethod = "DecodeVU0Mem";
  let mayLoad = 1;
}
def SQC2 : InstSE<(outs), (ins VU0VFOpnd:$vf, mem:$addr), "sqc2\t$vf, $addr",
                  [], FrmFI>, VU0_SQC2_FM {
  let DecoderMethod = "DecodeVU0Mem";
  let mayStore = 1;
}
}

//===----------------------------------------------------------------------===//
// Remaining instruction families. Bit layouts below were re-derived
// directly from decode_mips_operand's letter table (opcodes/mips-opc.c
// lines ~39-216: "+L"/SPECIAL(2,21,..)=bits22-21 single-lane select,
// "+M"/SPECIAL(2,23,..)=bits24-23, "+N"/SPECIAL(2,0,..)=bits1-0, "+g"/
// SINT(5,6)=bits10-6 signed immediate, "+f"/INT_ADJ(15,6,32767,3,..)=
// bits20-6 raw field whose value is the target address >>3, "+m"/"+q"/
// "+r"/"+y"/REG(0,0,..)=implicit 0-bit ACC/Q/R/I registers), each cross-
// checked against the literal opcode/mask hex in the table (nibble-by-
// nibble bit extraction, same method already spot-verified earlier this
// session against real GNU `as` output). Two families
// (vopmula/vopmsub/vclipw) turned out to have their channel-select bits
// baked permanently into the fixed opcode rather than being genuinely
// selectable - real hardware only ever defines one legal form of them.
//===----------------------------------------------------------------------===//

// vopmula (outer-product multiply, ACC-writing) / vopmsub (outer-product
// multiply-subtract, FD-writing): opcodes/mips-opc.c's mask shows the
// channel field (bits24-21) is entirely FIXED at 0b1110 ("xyz") for both -
// real hardware only defines the 3-component cross-product form, so no
// per-instruction mask choice exists (unlike vadd/vmula/etc above). Reuses
// the existing VU0_ACC_FM/VU0_3R_FM shapes directly with that mask baked
// in; vopmula=0x2fe (11-bit funct), vopmsub=0x2e (6-bit funct).
// opcodes/mips-opc.c lists both "vopmula"/"vopmsub" and their
// ".xyz"-suffixed spellings as separate, identically-encoded mnemonics
// (the channel field being fixed rather than selectable means there's
// no real distinction) - both accepted here for the same reason. vopmula
// also needs the explicit $ACC operand real gas requires, same as the
// rest of the ACC-writing family (VU0_ACC_DESC).
let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "Mips" in {
def VOPMULA : InstSE<(outs), (ins VU0ACCOpnd:$acc, VU0VFOpnd:$fs, VU0VFOpnd:$ft),
                     "vopmula\t$acc, $fs, $ft", [], FrmOther>, VU0_ACC_FM<0x2fe, 0b1110> {
  let Defs = [ACC];
}
def VOPMSUB : InstSE<(outs VU0VFOpnd:$fd), (ins VU0VFOpnd:$fs, VU0VFOpnd:$ft),
                     "vopmsub\t$fd, $fs, $ft", [], FrmOther>, VU0_3R_FM<0x2e, 0b1110>;
}
// ".xyz"-suffixed spellings of both - identical encoding (the channel
// field is fixed, not selectable, see comment above), so these are
// InstAlias, not second Instruction defs (would collide in the
// disassembler table, same reasoning as VU0_3R_Arith's bare-mnemonic
// alias further up this file).
def : MipsInstAlias<"vopmula.xyz $acc, $fs, $ft",
        (VOPMULA VU0ACCOpnd:$acc, VU0VFOpnd:$fs, VU0VFOpnd:$ft), 1>;
def : MipsInstAlias<"vopmsub.xyz $fd, $fs, $ft",
        (VOPMSUB VU0VFOpnd:$fd, VU0VFOpnd:$fs, VU0VFOpnd:$ft), 1>;

// vclipw: FS-mask AND FT-lane are BOTH fixed in the opcode/mask (mask ==
// 0xffe007ff leaves only fs/ft register-number bits variable - the 4-bit
// channel nibble at 24-21 is fixed 0b1110 "xyz" and the 2-bit FT-lane at
// bits1-0 is fixed 0b11 "w") - real hardware's clip test is defined only
// as "FS.xyz vs FT.w", there is no other legal encoding.
class VU0_CLIPW_FM : StdArch {
  bits<5> fs;
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = 0b1110;
  let Inst{20-16} = ft;
  let Inst{15-11} = fs;
  let Inst{10-0}  = 0x1ff;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "Mips" in
def VCLIPW : InstSE<(outs), (ins VU0VFOpnd:$fs, VU0VFOpnd:$ft),
                    "vclipw\t$fs, $ft", [], FrmOther>, VU0_CLIPW_FM;
// opcodes/mips-opc.c also lists a ".xyz"-suffixed spelling, identical
// encoding (same reasoning as vopmula.xyz/vopmsub.xyz above).
def : MipsInstAlias<"vclipw.xyz $fs, $ft",
        (VCLIPW VU0VFOpnd:$fs, VU0VFOpnd:$ft), 1>;

// vrget/vrnext: FT-slot dest with the usual 15-combo channel mask, source
// is the implicit $R register (0 encoded bits, same "+r" REG(0,0,R5900_R)
// as vrinit/vrxor below) - reuses the FT+mask shape but with a 16-bit
// fixed low half (bits15-0) instead of an 11-bit funct, since there's no
// FS register field at all here (opcodes/mips-opc.c: vrget=0x4a00043d,
// vrnext=0x4a00043c, mask=0xfe00ffff).
class VU0_R2VF_FM<bits<16> lowfix, bits<4> mask> : StdArch {
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = ft;
  let Inst{15-0}  = lowfix;
}

class VU0_R2VF_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$ft), (ins), !strconcat(opstr, "\t$ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let Uses = [VU0R];
}

multiclass VU0_R2VF_Arith<string opstr, bits<16> lowfix> {
  def _x    : VU0_R2VF_DESC<opstr#".x">,    VU0_R2VF_FM<lowfix, 0b1000>;
  def _y    : VU0_R2VF_DESC<opstr#".y">,    VU0_R2VF_FM<lowfix, 0b0100>;
  def _z    : VU0_R2VF_DESC<opstr#".z">,    VU0_R2VF_FM<lowfix, 0b0010>;
  def _w    : VU0_R2VF_DESC<opstr#".w">,    VU0_R2VF_FM<lowfix, 0b0001>;
  def _xy   : VU0_R2VF_DESC<opstr#".xy">,   VU0_R2VF_FM<lowfix, 0b1100>;
  def _xz   : VU0_R2VF_DESC<opstr#".xz">,   VU0_R2VF_FM<lowfix, 0b1010>;
  def _xw   : VU0_R2VF_DESC<opstr#".xw">,   VU0_R2VF_FM<lowfix, 0b1001>;
  def _yz   : VU0_R2VF_DESC<opstr#".yz">,   VU0_R2VF_FM<lowfix, 0b0110>;
  def _yw   : VU0_R2VF_DESC<opstr#".yw">,   VU0_R2VF_FM<lowfix, 0b0101>;
  def _zw   : VU0_R2VF_DESC<opstr#".zw">,   VU0_R2VF_FM<lowfix, 0b0011>;
  def _xyz  : VU0_R2VF_DESC<opstr#".xyz">,  VU0_R2VF_FM<lowfix, 0b1110>;
  def _xyw  : VU0_R2VF_DESC<opstr#".xyw">,  VU0_R2VF_FM<lowfix, 0b1101>;
  def _xzw  : VU0_R2VF_DESC<opstr#".xzw">,  VU0_R2VF_FM<lowfix, 0b1011>;
  def _yzw  : VU0_R2VF_DESC<opstr#".yzw">,  VU0_R2VF_FM<lowfix, 0b0111>;
  def _xyzw : VU0_R2VF_DESC<opstr#".xyzw">, VU0_R2VF_FM<lowfix, 0b1111>;
}

defm VRGET  : VU0_R2VF_Arith<"vrget", 0x043d>;
defm VRNEXT : VU0_R2VF_Arith<"vrnext", 0x043c>;

// vrinit/vrxor: implicit $R dest, FS source with a single-lane select
// (+L, bits22-21) rather than a 4-bit mask - only 4 forms exist (one per
// lane), not 15. opcodes/mips-opc.c: vrinit=0x4a00043e, vrxor=0x4a00043f,
// mask=0xff9f07ff (bits24-23 and 20-16 fixed at 0, confirmed by nibble
// extraction from the base opcode, not assumed).
class VU0_R1LANE_FM<bits<11> funct, bits<2> lane> : StdArch {
  bits<5> fs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-23} = 0b00;
  let Inst{22-21} = lane;
  let Inst{20-16} = 0b00000;
  let Inst{15-11} = fs;
  let Inst{10-0}  = funct;
}

class VU0_R1LANE_DESC<string opstr> :
  InstSE<(outs), (ins VU0VFOpnd:$fs), !strconcat(opstr, "\t$fs"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

// Lane code per tc-mips.c's match_vu0_suffix_operand ("uval = 4 - ffs(uval)"
// applied to the x=8/y=4/z=2/w=1 channel bit): x=0, y=1, z=2, w=3.
multiclass VU0_R1LANE_Arith<string opstr, bits<11> funct> {
  def _x : VU0_R1LANE_DESC<opstr#".x">, VU0_R1LANE_FM<funct, 0b00> { let Defs = [VU0R]; }
  def _y : VU0_R1LANE_DESC<opstr#".y">, VU0_R1LANE_FM<funct, 0b01> { let Defs = [VU0R]; }
  def _z : VU0_R1LANE_DESC<opstr#".z">, VU0_R1LANE_FM<funct, 0b10> { let Defs = [VU0R]; }
  def _w : VU0_R1LANE_DESC<opstr#".w">, VU0_R1LANE_FM<funct, 0b11> { let Defs = [VU0R]; }
}

defm VRINIT : VU0_R1LANE_Arith<"vrinit", 0x43e>;
// vrxor both reads and writes $R (X ^= fs.lane).
let Uses = [VU0R] in
defm VRXOR : VU0_R1LANE_Arith<"vrxor", 0x43f>;

// vmtir: real VI dest (+0, bits20-16) instead of implicit-R, FS source
// with a single-lane select (+L). opcodes/mips-opc.c: vmtir=0x4a0003fc,
// mask=0xff8007ff (bits24-23 fixed 0, confirmed by nibble extraction).
class VU0_VMTIR_FM : StdArch {
  bits<5> vi;
  bits<5> fs;
  bits<2> lane;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-23} = 0b00;
  let Inst{22-21} = lane;
  let Inst{20-16} = vi;
  let Inst{15-11} = fs;
  let Inst{10-0}  = 0x3fc;
}

class VU0_VMTIR_DESC<string opstr> :
  InstSE<(outs VU0VIOpnd:$vi), (ins VU0VFOpnd:$fs), !strconcat(opstr, "\t$vi, $fs"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

def VMTIR_x : VU0_VMTIR_DESC<"vmtir.x">, VU0_VMTIR_FM { let lane = 0b00; }
def VMTIR_y : VU0_VMTIR_DESC<"vmtir.y">, VU0_VMTIR_FM { let lane = 0b01; }
def VMTIR_z : VU0_VMTIR_DESC<"vmtir.z">, VU0_VMTIR_FM { let lane = 0b10; }
def VMTIR_w : VU0_VMTIR_DESC<"vmtir.w">, VU0_VMTIR_FM { let lane = 0b11; }

// vmfir (VI->VF, masked dest at the FT slot) / vlqd,vlqi (128-bit
// memory->VF load through a VI base register, masked dest at the FT
// slot, no offset - the pre/post-increment GAS syntax ("(#-+9)"/"(+9#+)")
// is real hardware auto-inc/dec baked into VU0 execution, not an
// assembler-level addressing computation, so it needs no special operand
// parsing - the encoded bits are just [mask][FT=dest][FS-slot=VI base]).
// opcodes/mips-opc.c funct (low 11 bits): vmfir=0x3fd, vlqd=0x37e,
// vlqi=0x37c; all share mask=0xfe0007ff.
class VU0_VI2VF_FM<bits<11> funct, bits<4> mask> : StdArch {
  bits<5> ft;
  bits<5> vi;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = ft;
  let Inst{15-11} = vi;
  let Inst{10-0}  = funct;
}

class VU0_VI2VF_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$ft), (ins VU0VIOpnd:$vi), !strconcat(opstr, "\t$ft, $vi"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

multiclass VU0_VI2VF_Arith<string opstr, bits<11> funct> {
  def _x    : VU0_VI2VF_DESC<opstr#".x">,    VU0_VI2VF_FM<funct, 0b1000>;
  def _y    : VU0_VI2VF_DESC<opstr#".y">,    VU0_VI2VF_FM<funct, 0b0100>;
  def _z    : VU0_VI2VF_DESC<opstr#".z">,    VU0_VI2VF_FM<funct, 0b0010>;
  def _w    : VU0_VI2VF_DESC<opstr#".w">,    VU0_VI2VF_FM<funct, 0b0001>;
  def _xy   : VU0_VI2VF_DESC<opstr#".xy">,   VU0_VI2VF_FM<funct, 0b1100>;
  def _xz   : VU0_VI2VF_DESC<opstr#".xz">,   VU0_VI2VF_FM<funct, 0b1010>;
  def _xw   : VU0_VI2VF_DESC<opstr#".xw">,   VU0_VI2VF_FM<funct, 0b1001>;
  def _yz   : VU0_VI2VF_DESC<opstr#".yz">,   VU0_VI2VF_FM<funct, 0b0110>;
  def _yw   : VU0_VI2VF_DESC<opstr#".yw">,   VU0_VI2VF_FM<funct, 0b0101>;
  def _zw   : VU0_VI2VF_DESC<opstr#".zw">,   VU0_VI2VF_FM<funct, 0b0011>;
  def _xyz  : VU0_VI2VF_DESC<opstr#".xyz">,  VU0_VI2VF_FM<funct, 0b1110>;
  def _xyw  : VU0_VI2VF_DESC<opstr#".xyw">,  VU0_VI2VF_FM<funct, 0b1101>;
  def _xzw  : VU0_VI2VF_DESC<opstr#".xzw">,  VU0_VI2VF_FM<funct, 0b1011>;
  def _yzw  : VU0_VI2VF_DESC<opstr#".yzw">,  VU0_VI2VF_FM<funct, 0b0111>;
  def _xyzw : VU0_VI2VF_DESC<opstr#".xyzw">, VU0_VI2VF_FM<funct, 0b1111>;
}

defm VMFIR : VU0_VI2VF_Arith<"vmfir", 0x3fd>;
defm VLQD  : VU0_VI2VF_Arith<"vlqd", 0x37e>;
defm VLQI  : VU0_VI2VF_Arith<"vlqi", 0x37c>;

// vsqd/vsqi mirror vlqd/vlqi (128-bit VF->memory store through a VI base
// register) but with the register slots swapped: masked VF source sits
// at the FS slot (bits15-11) and the VI base at the FT slot (bits20-16)
// - opcodes/mips-opc.c's "+6+K,(#-+0)"/"+6+K,(+0#+)" vs vlqd/vlqi's
// "+7+K,(#-+9)"/"+7+K,(+9#+)". funct: vsqd=0x37f, vsqi=0x37d.
class VU0_VF2VI_FM<bits<11> funct, bits<4> mask> : StdArch {
  bits<5> vi;
  bits<5> fs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = vi;
  let Inst{15-11} = fs;
  let Inst{10-0}  = funct;
}

class VU0_VF2VI_DESC<string opstr> :
  InstSE<(outs), (ins VU0VFOpnd:$fs, VU0VIOpnd:$vi), !strconcat(opstr, "\t$fs, $vi"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

multiclass VU0_VF2VI_Arith<string opstr, bits<11> funct> {
  def _x    : VU0_VF2VI_DESC<opstr#".x">,    VU0_VF2VI_FM<funct, 0b1000>;
  def _y    : VU0_VF2VI_DESC<opstr#".y">,    VU0_VF2VI_FM<funct, 0b0100>;
  def _z    : VU0_VF2VI_DESC<opstr#".z">,    VU0_VF2VI_FM<funct, 0b0010>;
  def _w    : VU0_VF2VI_DESC<opstr#".w">,    VU0_VF2VI_FM<funct, 0b0001>;
  def _xy   : VU0_VF2VI_DESC<opstr#".xy">,   VU0_VF2VI_FM<funct, 0b1100>;
  def _xz   : VU0_VF2VI_DESC<opstr#".xz">,   VU0_VF2VI_FM<funct, 0b1010>;
  def _xw   : VU0_VF2VI_DESC<opstr#".xw">,   VU0_VF2VI_FM<funct, 0b1001>;
  def _yz   : VU0_VF2VI_DESC<opstr#".yz">,   VU0_VF2VI_FM<funct, 0b0110>;
  def _yw   : VU0_VF2VI_DESC<opstr#".yw">,   VU0_VF2VI_FM<funct, 0b0101>;
  def _zw   : VU0_VF2VI_DESC<opstr#".zw">,   VU0_VF2VI_FM<funct, 0b0011>;
  def _xyz  : VU0_VF2VI_DESC<opstr#".xyz">,  VU0_VF2VI_FM<funct, 0b1110>;
  def _xyw  : VU0_VF2VI_DESC<opstr#".xyw">,  VU0_VF2VI_FM<funct, 0b1101>;
  def _xzw  : VU0_VF2VI_DESC<opstr#".xzw">,  VU0_VF2VI_FM<funct, 0b1011>;
  def _yzw  : VU0_VF2VI_DESC<opstr#".yzw">,  VU0_VF2VI_FM<funct, 0b0111>;
  def _xyzw : VU0_VF2VI_DESC<opstr#".xyzw">, VU0_VF2VI_FM<funct, 0b1111>;
}

defm VSQD : VU0_VF2VI_Arith<"vsqd", 0x37f>;
defm VSQI : VU0_VF2VI_Arith<"vsqi", 0x37d>;

// vilwr.{w,x,y,z}/viswr.{w,x,y,z}: 16-bit int load/store through a VI
// base register (memory<->VI, not memory<->VF) - GAS defines these as 4
// entirely separate opcode-table entries per channel (not a maskable
// operand at all: "+0,(+9)" has no "+K"/"+L" in its operand string), each
// differing from the others by exactly one fixed bit in 24-21 (confirmed
// by XORing the four base opcodes: bit21=w, bit22=z, bit23=y, bit24=x -
// same bit-per-channel convention as the mask field elsewhere, just with
// only one bit ever set). funct (low 11 bits, shared within each
// mnemonic): vilwr.*=0x3fe, viswr.*=0x3ff.
class VU0_ILWR_FM<bits<11> funct, bits<4> chbit> : StdArch {
  bits<5> vd;
  bits<5> vs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = chbit;
  let Inst{20-16} = vd;
  let Inst{15-11} = vs;
  let Inst{10-0}  = funct;
}

class VU0_ILWR_DESC<string opstr> :
  InstSE<(outs VU0VIOpnd:$vd), (ins VU0VIOpnd:$vs), !strconcat(opstr, "\t$vd, $vs"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let mayLoad = 1;
}

class VU0_ISWR_DESC<string opstr> :
  InstSE<(outs), (ins VU0VIOpnd:$vd, VU0VIOpnd:$vs), !strconcat(opstr, "\t$vd, $vs"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let mayStore = 1;
}

def VILWR_W : VU0_ILWR_DESC<"vilwr.w">, VU0_ILWR_FM<0x3fe, 0b0001>;
def VILWR_X : VU0_ILWR_DESC<"vilwr.x">, VU0_ILWR_FM<0x3fe, 0b1000>;
def VILWR_Y : VU0_ILWR_DESC<"vilwr.y">, VU0_ILWR_FM<0x3fe, 0b0100>;
def VILWR_Z : VU0_ILWR_DESC<"vilwr.z">, VU0_ILWR_FM<0x3fe, 0b0010>;
def VISWR_W : VU0_ISWR_DESC<"viswr.w">, VU0_ILWR_FM<0x3ff, 0b0001>;
def VISWR_X : VU0_ISWR_DESC<"viswr.x">, VU0_ILWR_FM<0x3ff, 0b1000>;
def VISWR_Y : VU0_ISWR_DESC<"viswr.y">, VU0_ILWR_FM<0x3ff, 0b0100>;
def VISWR_Z : VU0_ISWR_DESC<"viswr.z">, VU0_ILWR_FM<0x3ff, 0b0010>;

// vdiv/vrsqrt: implicit $Q dest, FS and FT each carry their own
// independent single-lane select (+L@22-21 on FS, +M@24-23 on FT) rather
// than a shared mask - 16 real forms (4x4), not 15. opcodes/mips-opc.c:
// vdiv=0x4a0003bc, vrsqrt=0x4a0003be, mask=0xfe0007ff (bits24-21 fully
// variable this time - both L and M together, unlike vsqrt below where
// the missing FS operand leaves bits22-21 fixed instead).
class VU0_QDIV_FM<bits<11> funct, bits<2> flane, bits<2> mlane> : StdArch {
  bits<5> fs;
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-23} = mlane;
  let Inst{22-21} = flane;
  let Inst{20-16} = ft;
  let Inst{15-11} = fs;
  let Inst{10-0}  = funct;
}

// Real GNU as syntax (opcodes/mips-opc.c: "+q,+6+L,+7+M") has no dotted
// mnemonic suffix at all - the lane select is spelled as a trailing
// x/y/z/w letter on the fs/ft register names themselves ("vrsqrt $Q,
// $vf0w, $vf2w"), a real, meaningful 2-bit field per operand (unlike
// every OTHER VU0 operand suffix in this file, which is decorative) -
// found while porting sdk-core's math3d.c. FSOpnd/FTOpnd are the
// matching VU0VFx/y/z/wOpnd lane-specific classes (MipsRegisterInfo.td)
// so the AsmMatcher picks the right encoding by which lane letters were
// actually typed, same bare "vdiv"/"vrsqrt" mnemonic for all 16.
class VU0_QDIV_DESC<string opstr, RegisterOperand FSOpnd,
                     RegisterOperand FTOpnd> :
  InstSE<(outs), (ins VU0QOpnd:$q, FSOpnd:$fs, FTOpnd:$ft),
         !strconcat(opstr, "\t$q, $fs, $ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let Defs = [VU0Q];
}

multiclass VU0_QDIV_Arith<string opstr, bits<11> funct> {
  def _xx : VU0_QDIV_DESC<opstr, VU0VFxOpnd, VU0VFxOpnd>, VU0_QDIV_FM<funct, 0b00, 0b00>;
  def _xy : VU0_QDIV_DESC<opstr, VU0VFxOpnd, VU0VFyOpnd>, VU0_QDIV_FM<funct, 0b00, 0b01>;
  def _xz : VU0_QDIV_DESC<opstr, VU0VFxOpnd, VU0VFzOpnd>, VU0_QDIV_FM<funct, 0b00, 0b10>;
  def _xw : VU0_QDIV_DESC<opstr, VU0VFxOpnd, VU0VFwOpnd>, VU0_QDIV_FM<funct, 0b00, 0b11>;
  def _yx : VU0_QDIV_DESC<opstr, VU0VFyOpnd, VU0VFxOpnd>, VU0_QDIV_FM<funct, 0b01, 0b00>;
  def _yy : VU0_QDIV_DESC<opstr, VU0VFyOpnd, VU0VFyOpnd>, VU0_QDIV_FM<funct, 0b01, 0b01>;
  def _yz : VU0_QDIV_DESC<opstr, VU0VFyOpnd, VU0VFzOpnd>, VU0_QDIV_FM<funct, 0b01, 0b10>;
  def _yw : VU0_QDIV_DESC<opstr, VU0VFyOpnd, VU0VFwOpnd>, VU0_QDIV_FM<funct, 0b01, 0b11>;
  def _zx : VU0_QDIV_DESC<opstr, VU0VFzOpnd, VU0VFxOpnd>, VU0_QDIV_FM<funct, 0b10, 0b00>;
  def _zy : VU0_QDIV_DESC<opstr, VU0VFzOpnd, VU0VFyOpnd>, VU0_QDIV_FM<funct, 0b10, 0b01>;
  def _zz : VU0_QDIV_DESC<opstr, VU0VFzOpnd, VU0VFzOpnd>, VU0_QDIV_FM<funct, 0b10, 0b10>;
  def _zw : VU0_QDIV_DESC<opstr, VU0VFzOpnd, VU0VFwOpnd>, VU0_QDIV_FM<funct, 0b10, 0b11>;
  def _wx : VU0_QDIV_DESC<opstr, VU0VFwOpnd, VU0VFxOpnd>, VU0_QDIV_FM<funct, 0b11, 0b00>;
  def _wy : VU0_QDIV_DESC<opstr, VU0VFwOpnd, VU0VFyOpnd>, VU0_QDIV_FM<funct, 0b11, 0b01>;
  def _wz : VU0_QDIV_DESC<opstr, VU0VFwOpnd, VU0VFzOpnd>, VU0_QDIV_FM<funct, 0b11, 0b10>;
  def _ww : VU0_QDIV_DESC<opstr, VU0VFwOpnd, VU0VFwOpnd>, VU0_QDIV_FM<funct, 0b11, 0b11>;
}

defm VDIV   : VU0_QDIV_Arith<"vdiv", 0x3bc>;
defm VRSQRT : VU0_QDIV_Arith<"vrsqrt", 0x3be>;

// vsqrt: implicit $Q dest, FT-only single-lane select (+M) - no FS
// operand at all, so (unlike vdiv/vrsqrt above) bits22-21 have no
// operand to bind to and come out fixed at 0b01 in the opcode/mask
// (confirmed by nibble extraction of 0x4a2003bd, not assumed to be 0).
class VU0_QSQRT_FM<bits<2> mlane> : StdArch {
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-23} = mlane;
  let Inst{22}    = 0;
  let Inst{21}    = 1;
  let Inst{20-16} = ft;
  let Inst{15-11} = 0b00000;
  let Inst{10-0}  = 0x3bd;
}

// Bare mnemonic, lane-typed $ft operand - same real-syntax story as
// VU0_QDIV_DESC above (opcodes/mips-opc.c: vsqrt = "+q,+7+M").
class VU0_QSQRT_DESC<string opstr, RegisterOperand FTOpnd> :
  InstSE<(outs), (ins VU0QOpnd:$q, FTOpnd:$ft),
         !strconcat(opstr, "\t$q, $ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let Defs = [VU0Q];
}

def VSQRT_x : VU0_QSQRT_DESC<"vsqrt", VU0VFxOpnd>, VU0_QSQRT_FM<0b00>;
def VSQRT_y : VU0_QSQRT_DESC<"vsqrt", VU0VFyOpnd>, VU0_QSQRT_FM<0b01>;
def VSQRT_z : VU0_QSQRT_DESC<"vsqrt", VU0VFzOpnd>, VU0_QSQRT_FM<0b10>;
def VSQRT_w : VU0_QSQRT_DESC<"vsqrt", VU0VFwOpnd>, VU0_QSQRT_FM<0b11>;

// viaddi: VI dest/src like the plain integer ops above, but a 5-bit
// signed immediate (+g, SINT(5,6) => bits10-6) in place of a third VI
// register - reuses VU0_INT_FM's "no channel mask" convention
// (bits24-21 fixed 0, confirmed for viaddi too) but with dest at the FT
// slot (bits20-16) rather than FD, matching mips-opc.c's "+0,+9,+g"
// operand order. opcodes/mips-opc.c: viaddi=0x4a000032, funct=0x32.
def vu0_simm5 : Operand<i32>;

class VU0_VIADDI_FM : StdArch {
  bits<5> vd;
  bits<5> vs;
  bits<5> imm;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = 0;
  let Inst{20-16} = vd;
  let Inst{15-11} = vs;
  let Inst{10-6}  = imm;
  let Inst{5-0}   = 0x32;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "Mips" in
def VIADDI : InstSE<(outs VU0VIOpnd:$vd), (ins VU0VIOpnd:$vs, vu0_simm5:$imm),
                    "viaddi\t$vd, $vs, $imm", [], FrmOther>, VU0_VIADDI_FM;

// vcallms: 15-bit micro-program address field (+f, INT_ADJ(15,6,32767,3,
// true)) whose raw encoded value is the byte address right-shifted by 3
// (VU micro-instructions are 8 bytes each) - same shifted-immediate
// mechanism already used elsewhere in this backend for branch/jump
// targets (see getSimm23Lsl2Encoding), just a different shift amount;
// implemented via a matching getVU0MicroAddrEncoding in
// MipsMCCodeEmitter.cpp. opcodes/mips-opc.c: vcallms=0x4a000038,
// funct=0x38 (bits24-21 fixed 0, same "no mask" convention).
def vu0_microaddr : Operand<i32> {
  let EncoderMethod = "getVU0MicroAddrEncoding";
}

class VU0_CALLMS_FM : StdArch {
  bits<15> addr;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = 0;
  let Inst{20-6}  = addr;
  let Inst{5-0}   = 0x38;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "Mips" in
def VCALLMS : InstSE<(outs), (ins vu0_microaddr:$addr), "vcallms\t$addr", [],
                     FrmOther>, VU0_CALLMS_FM;

// vcallmsr: same call-microsubroutine op, but the target comes from a VI
// register instead of a literal address. opcodes/mips-opc.c:
// vcallmsr=0x4a000039, funct=0x39 (bits24-16 fixed 0, confirmed by
// nibble extraction).
class VU0_CALLMSR_FM : StdArch {
  bits<5> vs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = 0;
  let Inst{20-16} = 0;
  let Inst{15-11} = vs;
  let Inst{10-0}  = 0x039;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1, DecoderNamespace = "Mips" in
def VCALLMSR : InstSE<(outs), (ins VU0VIOpnd:$vs), "vcallmsr\t$vs", [],
                      FrmOther>, VU0_CALLMSR_FM;

// bc2eqz/bc2nez were investigated and NOT implemented: opcodes/mips-opc.c
// tags them ISA=I37 (MIPS32 Release 6), and real GNU `as -mcpu=r5900`
// confirms this by rejecting them outright ("opcode not supported on
// this processor: r5900 (mips3) `bc2eqz $2,1f'") - they are a MIPS-ISA-
// table artifact, not a real R5900/VU0 instruction, so implementing them
// would add something PCSX2/real hardware don't actually support.

// More FD-writing 3-operand arithmetic, same VU0_3R_Arith shape as
// vadd/vsub/vmul already defined above. opcodes/mips-opc.c funct values
// (low 6 bits, template fields zeroed): vmadd=0x29, vmax=0x2b,
// vmini=0x2f, vmsub=0x2d.
defm VMADD : VU0_3R_Arith<"vmadd", 0x29>;
defm VMAX  : VU0_3R_Arith<"vmax", 0x2b>;
defm VMINI : VU0_3R_Arith<"vmini", 0x2f>;
defm VMSUB : VU0_3R_Arith<"vmsub", 0x2d>;

// Single-lane-broadcast variants (vaddx/vaddy/... - ft's value is still a
// real FS-shaped operand, but only its named lane is used; that's already
// baked into the distinct funct value per mips-opc.c, nothing extra to
// encode). Same VU0_3R_FM shape/multiclass, just more funct values.
defm VADDX : VU0_3R_Arith<"vaddx", 0x00>;
defm VADDY : VU0_3R_Arith<"vaddy", 0x01>;
defm VADDZ : VU0_3R_Arith<"vaddz", 0x02>;
defm VADDW : VU0_3R_Arith<"vaddw", 0x03>;
defm VSUBX : VU0_3R_Arith<"vsubx", 0x04>;
defm VSUBY : VU0_3R_Arith<"vsuby", 0x05>;
defm VSUBZ : VU0_3R_Arith<"vsubz", 0x06>;
defm VSUBW : VU0_3R_Arith<"vsubw", 0x07>;
defm VMADDX : VU0_3R_Arith<"vmaddx", 0x08>;
defm VMADDY : VU0_3R_Arith<"vmaddy", 0x09>;
defm VMADDZ : VU0_3R_Arith<"vmaddz", 0x0a>;
defm VMADDW : VU0_3R_Arith<"vmaddw", 0x0b>;
defm VMSUBX : VU0_3R_Arith<"vmsubx", 0x0c>;
defm VMSUBY : VU0_3R_Arith<"vmsuby", 0x0d>;
defm VMSUBZ : VU0_3R_Arith<"vmsubz", 0x0e>;
defm VMSUBW : VU0_3R_Arith<"vmsubw", 0x0f>;
defm VMAXX : VU0_3R_Arith<"vmaxx", 0x10>;
defm VMAXY : VU0_3R_Arith<"vmaxy", 0x11>;
defm VMAXZ : VU0_3R_Arith<"vmaxz", 0x12>;
defm VMAXW : VU0_3R_Arith<"vmaxw", 0x13>;
defm VMINIX : VU0_3R_Arith<"vminix", 0x14>;
defm VMINIY : VU0_3R_Arith<"vminiy", 0x15>;
defm VMINIZ : VU0_3R_Arith<"vminiz", 0x16>;
defm VMINIW : VU0_3R_Arith<"vminiw", 0x17>;
defm VMULX : VU0_3R_Arith<"vmulx", 0x18>;
defm VMULY : VU0_3R_Arith<"vmuly", 0x19>;
defm VMULZ : VU0_3R_Arith<"vmulz", 0x1a>;
defm VMULW : VU0_3R_Arith<"vmulw", 0x1b>;

// More ACC-writing 2-operand arithmetic (VU0_ACC_Arith, 11-bit funct).
// vmadda=0x2bd, vmsuba=0x2fd.
defm VMADDA : VU0_ACC_Arith<"vmadda", 0x2bd>;
defm VMSUBA : VU0_ACC_Arith<"vmsuba", 0x2fd>;

defm VADDAX : VU0_ACC_Arith<"vaddax", 0x03c>;
defm VADDAY : VU0_ACC_Arith<"vadday", 0x03d>;
defm VADDAZ : VU0_ACC_Arith<"vaddaz", 0x03e>;
defm VADDAW : VU0_ACC_Arith<"vaddaw", 0x03f>;
defm VSUBAX : VU0_ACC_Arith<"vsubax", 0x07c>;
defm VSUBAY : VU0_ACC_Arith<"vsubay", 0x07d>;
defm VSUBAZ : VU0_ACC_Arith<"vsubaz", 0x07e>;
defm VSUBAW : VU0_ACC_Arith<"vsubaw", 0x07f>;
defm VMADDAX : VU0_ACC_Arith<"vmaddax", 0x0bc>;
defm VMADDAY : VU0_ACC_Arith<"vmadday", 0x0bd>;
defm VMADDAZ : VU0_ACC_Arith<"vmaddaz", 0x0be>;
defm VMADDAW : VU0_ACC_Arith<"vmaddaw", 0x0bf>;
defm VMSUBAX : VU0_ACC_Arith<"vmsubax", 0x0fc>;
defm VMSUBAY : VU0_ACC_Arith<"vmsubay", 0x0fd>;
defm VMSUBAZ : VU0_ACC_Arith<"vmsubaz", 0x0fe>;
defm VMSUBAW : VU0_ACC_Arith<"vmsubaw", 0x0ff>;
defm VMULAX : VU0_ACC_Arith<"vmulax", 0x1bc>;
defm VMULAY : VU0_ACC_Arith<"vmulay", 0x1bd>;
defm VMULAZ : VU0_ACC_Arith<"vmulaz", 0x1be>;
defm VMULAW : VU0_ACC_Arith<"vmulaw", 0x1bf>;

// FD-writing arithmetic against the implicit $I/$Q registers (2 real VF
// operands - fd, fs - instead of 3; ft's bit-16 slot is unused/fixed 0,
// same as the mips-opc.c template). Reuses VU0_3R_FM with ft hardcoded.
class VU0_2R_FM<bits<6> funct, bits<4> mask> : StdArch {
  bits<5> fd;
  bits<5> fs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = 0;
  let Inst{15-11} = fs;
  let Inst{10-6}  = fd;
  let Inst{5-0}   = funct;
}

// Real GNU as also spells this family's implicit third source operand
// out explicitly ("vmulq.xyz $vf1, $vf1, $Q") - same story as
// VU0ACCOpnd/VU0QOpnd elsewhere in this file. Split by which special
// register each opstr actually uses (found while porting sdk-core's
// math3d.c, which only exercises the Q half so far).
class VU0_2R_Q_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$fd), (ins VU0VFOpnd:$fs, VU0QOpnd:$q),
         !strconcat(opstr, "\t$fd, $fs, $q"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

class VU0_2R_I_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$fd), (ins VU0VFOpnd:$fs, VU0IOpnd:$i),
         !strconcat(opstr, "\t$fd, $fs, $i"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

multiclass VU0_2R_Q_Arith<string opstr, bits<6> funct> {
  def _x    : VU0_2R_Q_DESC<opstr#".x">,    VU0_2R_FM<funct, 0b1000>;
  def _y    : VU0_2R_Q_DESC<opstr#".y">,    VU0_2R_FM<funct, 0b0100>;
  def _z    : VU0_2R_Q_DESC<opstr#".z">,    VU0_2R_FM<funct, 0b0010>;
  def _w    : VU0_2R_Q_DESC<opstr#".w">,    VU0_2R_FM<funct, 0b0001>;
  def _xy   : VU0_2R_Q_DESC<opstr#".xy">,   VU0_2R_FM<funct, 0b1100>;
  def _xz   : VU0_2R_Q_DESC<opstr#".xz">,   VU0_2R_FM<funct, 0b1010>;
  def _xw   : VU0_2R_Q_DESC<opstr#".xw">,   VU0_2R_FM<funct, 0b1001>;
  def _yz   : VU0_2R_Q_DESC<opstr#".yz">,   VU0_2R_FM<funct, 0b0110>;
  def _yw   : VU0_2R_Q_DESC<opstr#".yw">,   VU0_2R_FM<funct, 0b0101>;
  def _zw   : VU0_2R_Q_DESC<opstr#".zw">,   VU0_2R_FM<funct, 0b0011>;
  def _xyz  : VU0_2R_Q_DESC<opstr#".xyz">,  VU0_2R_FM<funct, 0b1110>;
  def _xyw  : VU0_2R_Q_DESC<opstr#".xyw">,  VU0_2R_FM<funct, 0b1101>;
  def _xzw  : VU0_2R_Q_DESC<opstr#".xzw">,  VU0_2R_FM<funct, 0b1011>;
  def _yzw  : VU0_2R_Q_DESC<opstr#".yzw">,  VU0_2R_FM<funct, 0b0111>;
  def _xyzw : VU0_2R_Q_DESC<opstr#".xyzw">, VU0_2R_FM<funct, 0b1111>;
  def : MipsInstAlias<!strconcat(opstr, " $fd, $fs, $q"),
          (!cast<Instruction>(NAME#"_xyzw") VU0VFOpnd:$fd, VU0VFOpnd:$fs,
                                             VU0QOpnd:$q), 1>;
}

multiclass VU0_2R_I_Arith<string opstr, bits<6> funct> {
  def _x    : VU0_2R_I_DESC<opstr#".x">,    VU0_2R_FM<funct, 0b1000>;
  def _y    : VU0_2R_I_DESC<opstr#".y">,    VU0_2R_FM<funct, 0b0100>;
  def _z    : VU0_2R_I_DESC<opstr#".z">,    VU0_2R_FM<funct, 0b0010>;
  def _w    : VU0_2R_I_DESC<opstr#".w">,    VU0_2R_FM<funct, 0b0001>;
  def _xy   : VU0_2R_I_DESC<opstr#".xy">,   VU0_2R_FM<funct, 0b1100>;
  def _xz   : VU0_2R_I_DESC<opstr#".xz">,   VU0_2R_FM<funct, 0b1010>;
  def _xw   : VU0_2R_I_DESC<opstr#".xw">,   VU0_2R_FM<funct, 0b1001>;
  def _yz   : VU0_2R_I_DESC<opstr#".yz">,   VU0_2R_FM<funct, 0b0110>;
  def _yw   : VU0_2R_I_DESC<opstr#".yw">,   VU0_2R_FM<funct, 0b0101>;
  def _zw   : VU0_2R_I_DESC<opstr#".zw">,   VU0_2R_FM<funct, 0b0011>;
  def _xyz  : VU0_2R_I_DESC<opstr#".xyz">,  VU0_2R_FM<funct, 0b1110>;
  def _xyw  : VU0_2R_I_DESC<opstr#".xyw">,  VU0_2R_FM<funct, 0b1101>;
  def _xzw  : VU0_2R_I_DESC<opstr#".xzw">,  VU0_2R_FM<funct, 0b1011>;
  def _yzw  : VU0_2R_I_DESC<opstr#".yzw">,  VU0_2R_FM<funct, 0b0111>;
  def _xyzw : VU0_2R_I_DESC<opstr#".xyzw">, VU0_2R_FM<funct, 0b1111>;
  def : MipsInstAlias<!strconcat(opstr, " $fd, $fs, $i"),
          (!cast<Instruction>(NAME#"_xyzw") VU0VFOpnd:$fd, VU0VFOpnd:$fs,
                                             VU0IOpnd:$i), 1>;
}

// opcodes/mips-opc.c funct values: vaddi=0x22, vaddq=0x20, vmaddi=0x23,
// vmaddq=0x21, vmuli=0x1e, vmulq=0x1c, vmsubi=0x27, vmsubq=0x25,
// vsubi=0x26, vsubq=0x24, vmaxi=0x1d, vminii=0x1f.
defm VADDI : VU0_2R_I_Arith<"vaddi", 0x22>;
defm VADDQ : VU0_2R_Q_Arith<"vaddq", 0x20>;
defm VMADDI : VU0_2R_I_Arith<"vmaddi", 0x23>;
defm VMADDQ : VU0_2R_Q_Arith<"vmaddq", 0x21>;
defm VMULI : VU0_2R_I_Arith<"vmuli", 0x1e>;
defm VMULQ : VU0_2R_Q_Arith<"vmulq", 0x1c>;
defm VMSUBI : VU0_2R_I_Arith<"vmsubi", 0x27>;
defm VMSUBQ : VU0_2R_Q_Arith<"vmsubq", 0x25>;
defm VSUBI : VU0_2R_I_Arith<"vsubi", 0x26>;
defm VSUBQ : VU0_2R_Q_Arith<"vsubq", 0x24>;
defm VMAXI : VU0_2R_I_Arith<"vmaxi", 0x1d>;
defm VMINII : VU0_2R_I_Arith<"vminii", 0x1f>;

// ACC-writing arithmetic against the implicit $I/$Q registers (1 real VF
// operand - fs only). Reuses VU0_ACC_FM with ft hardcoded via a dedicated
// FM (mirrors VU0_2R_FM's relationship to VU0_3R_FM).
class VU0_1R_ACC_FM<bits<11> funct, bits<4> mask> : StdArch {
  bits<5> fs;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = mask;
  let Inst{20-16} = 0;
  let Inst{15-11} = fs;
  let Inst{10-0}  = funct;
}

class VU0_1R_ACC_DESC<string opstr> :
  InstSE<(outs), (ins VU0ACCOpnd:$acc, VU0VFOpnd:$fs),
         !strconcat(opstr, "\t$acc, $fs"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let Defs = [ACC];
}

multiclass VU0_1R_ACC_Arith<string opstr, bits<11> funct> {
  def _x    : VU0_1R_ACC_DESC<opstr#".x">,    VU0_1R_ACC_FM<funct, 0b1000>;
  def _y    : VU0_1R_ACC_DESC<opstr#".y">,    VU0_1R_ACC_FM<funct, 0b0100>;
  def _z    : VU0_1R_ACC_DESC<opstr#".z">,    VU0_1R_ACC_FM<funct, 0b0010>;
  def _w    : VU0_1R_ACC_DESC<opstr#".w">,    VU0_1R_ACC_FM<funct, 0b0001>;
  def _xy   : VU0_1R_ACC_DESC<opstr#".xy">,   VU0_1R_ACC_FM<funct, 0b1100>;
  def _xz   : VU0_1R_ACC_DESC<opstr#".xz">,   VU0_1R_ACC_FM<funct, 0b1010>;
  def _xw   : VU0_1R_ACC_DESC<opstr#".xw">,   VU0_1R_ACC_FM<funct, 0b1001>;
  def _yz   : VU0_1R_ACC_DESC<opstr#".yz">,   VU0_1R_ACC_FM<funct, 0b0110>;
  def _yw   : VU0_1R_ACC_DESC<opstr#".yw">,   VU0_1R_ACC_FM<funct, 0b0101>;
  def _zw   : VU0_1R_ACC_DESC<opstr#".zw">,   VU0_1R_ACC_FM<funct, 0b0011>;
  def _xyz  : VU0_1R_ACC_DESC<opstr#".xyz">,  VU0_1R_ACC_FM<funct, 0b1110>;
  def _xyw  : VU0_1R_ACC_DESC<opstr#".xyw">,  VU0_1R_ACC_FM<funct, 0b1101>;
  def _xzw  : VU0_1R_ACC_DESC<opstr#".xzw">,  VU0_1R_ACC_FM<funct, 0b1011>;
  def _yzw  : VU0_1R_ACC_DESC<opstr#".yzw">,  VU0_1R_ACC_FM<funct, 0b0111>;
  def _xyzw : VU0_1R_ACC_DESC<opstr#".xyzw">, VU0_1R_ACC_FM<funct, 0b1111>;
  // See VU0_ACC_Arith's alias above - same bare-mnemonic shorthand.
  def : MipsInstAlias<!strconcat(opstr, " $acc, $fs"),
          (!cast<Instruction>(NAME#"_xyzw") VU0ACCOpnd:$acc, VU0VFOpnd:$fs), 1>;
}

// opcodes/mips-opc.c funct values (low 11 bits): vaddai=0x23e,
// vaddaq=0x23c, vmaddai=0x23f, vmaddaq=0x23d, vmulai=0x1fe, vmulaq=0x1fc,
// vmsubai=0x27f, vmsubaq=0x27d, vsubai=0x27e, vsubaq=0x27c.
defm VADDAI : VU0_1R_ACC_Arith<"vaddai", 0x23e>;
defm VADDAQ : VU0_1R_ACC_Arith<"vaddaq", 0x23c>;
defm VMADDAI : VU0_1R_ACC_Arith<"vmaddai", 0x23f>;
defm VMADDAQ : VU0_1R_ACC_Arith<"vmaddaq", 0x23d>;
defm VMULAI : VU0_1R_ACC_Arith<"vmulai", 0x1fe>;
defm VMULAQ : VU0_1R_ACC_Arith<"vmulaq", 0x1fc>;
defm VMSUBAI : VU0_1R_ACC_Arith<"vmsubai", 0x27f>;
defm VMSUBAQ : VU0_1R_ACC_Arith<"vmsubaq", 0x27d>;
defm VSUBAI : VU0_1R_ACC_Arith<"vsubai", 0x27e>;
defm VSUBAQ : VU0_1R_ACC_Arith<"vsubaq", 0x27c>;

// Move/convert family: dest at the FT bit-slot (20-16), source at FS
// (15-11), both real VF operands, 11-bit funct - same shape as
// VU0_ACC_FM, just with the FT slot bound to a real dest operand instead
// of being ACC-implicit. Reuses VU0_ACC_FM directly.
class VU0_MOV_DESC<string opstr> :
  InstSE<(outs VU0VFOpnd:$ft), (ins VU0VFOpnd:$fs),
         !strconcat(opstr, "\t$ft, $fs"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

multiclass VU0_MOV_Arith<string opstr, bits<11> funct> {
  def _x    : VU0_MOV_DESC<opstr#".x">,    VU0_ACC_FM<funct, 0b1000>;
  def _y    : VU0_MOV_DESC<opstr#".y">,    VU0_ACC_FM<funct, 0b0100>;
  def _z    : VU0_MOV_DESC<opstr#".z">,    VU0_ACC_FM<funct, 0b0010>;
  def _w    : VU0_MOV_DESC<opstr#".w">,    VU0_ACC_FM<funct, 0b0001>;
  def _xy   : VU0_MOV_DESC<opstr#".xy">,   VU0_ACC_FM<funct, 0b1100>;
  def _xz   : VU0_MOV_DESC<opstr#".xz">,   VU0_ACC_FM<funct, 0b1010>;
  def _xw   : VU0_MOV_DESC<opstr#".xw">,   VU0_ACC_FM<funct, 0b1001>;
  def _yz   : VU0_MOV_DESC<opstr#".yz">,   VU0_ACC_FM<funct, 0b0110>;
  def _yw   : VU0_MOV_DESC<opstr#".yw">,   VU0_ACC_FM<funct, 0b0101>;
  def _zw   : VU0_MOV_DESC<opstr#".zw">,   VU0_ACC_FM<funct, 0b0011>;
  def _xyz  : VU0_MOV_DESC<opstr#".xyz">,  VU0_ACC_FM<funct, 0b1110>;
  def _xyw  : VU0_MOV_DESC<opstr#".xyw">,  VU0_ACC_FM<funct, 0b1101>;
  def _xzw  : VU0_MOV_DESC<opstr#".xzw">,  VU0_ACC_FM<funct, 0b1011>;
  def _yzw  : VU0_MOV_DESC<opstr#".yzw">,  VU0_ACC_FM<funct, 0b0111>;
  def _xyzw : VU0_MOV_DESC<opstr#".xyzw">, VU0_ACC_FM<funct, 0b1111>;
}

// opcodes/mips-opc.c funct values: vabs=0x1fd, vftoi0=0x17c,
// vftoi4=0x17d, vftoi12=0x17e, vftoi15=0x17f, vitof0=0x13c,
// vitof4=0x13d, vitof12=0x13e, vitof15=0x13f, vmove=0x33c, vmr32=0x33d.
defm VABS : VU0_MOV_Arith<"vabs", 0x1fd>;
defm VFTOI0 : VU0_MOV_Arith<"vftoi0", 0x17c>;
defm VFTOI4 : VU0_MOV_Arith<"vftoi4", 0x17d>;
defm VFTOI12 : VU0_MOV_Arith<"vftoi12", 0x17e>;
defm VFTOI15 : VU0_MOV_Arith<"vftoi15", 0x17f>;
defm VITOF0 : VU0_MOV_Arith<"vitof0", 0x13c>;
defm VITOF4 : VU0_MOV_Arith<"vitof4", 0x13d>;
defm VITOF12 : VU0_MOV_Arith<"vitof12", 0x13e>;
defm VITOF15 : VU0_MOV_Arith<"vitof15", 0x13f>;
defm VMOVE : VU0_MOV_Arith<"vmove", 0x33c>;
defm VMR32 : VU0_MOV_Arith<"vmr32", 0x33d>;

// Integer (VI-register) arithmetic: plain 3-operand, no dest-field mask
// at all (mips-opc.c's mask=0xffe0003f confirms bits24-21 are part of
// the FIXED opcode here, not a variable field - unlike every VF-family
// instruction above).
class VU0_INT_FM<bits<6> funct> : StdArch {
  bits<5> fd;
  bits<5> fs;
  bits<5> ft;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25}    = 1;
  let Inst{24-21} = 0;
  let Inst{20-16} = ft;
  let Inst{15-11} = fs;
  let Inst{10-6}  = fd;
  let Inst{5-0}   = funct;
}

class VU0_INT_DESC<string opstr> :
  InstSE<(outs VU0VIOpnd:$fd), (ins VU0VIOpnd:$fs, VU0VIOpnd:$ft),
         !strconcat(opstr, "\t$fd, $fs, $ft"), [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
}

// opcodes/mips-opc.c: viadd=0x30, viand=0x34, vior=0x35, visub=0x31.
let Predicates = [HasVU0] in {
def VIADD : VU0_INT_DESC<"viadd">, VU0_INT_FM<0x30>;
def VIAND : VU0_INT_DESC<"viand">, VU0_INT_FM<0x34>;
def VIOR  : VU0_INT_DESC<"vior">,  VU0_INT_FM<0x35>;
def VISUB : VU0_INT_DESC<"visub">, VU0_INT_FM<0x31>;
}

// CFC2/CTC2: EE-side (not VU0-macro-mode-specific) COP2 control-register
// transfer. Found broken while porting sdk-core's libgs (ResetPath.s uses
// "cfc2 $a0, $28"/"ctc2 $a0, $28" against real EE clipping-flag control
// register 28) - the original MFC3OP-based defs here mismatched real
// syntax: MFC3OP is a 3-operand class (rt, rd, sel) built for COP0's
// MFC0-style select field, but opcodes/mips-opc.c's cfc2/ctc2 ("t,g" -
// cfc2=0x48400000, ctc2=0x48c00000, mask 0xffe007ff) are a plain
// 2-operand CFCz/CTCz form with no sel field at all (low 11 bits always
// zero). Own class instead, same op/mfmt-slot shape as MFC3OP_FM
// (mfmt=2 for CFCz / 6 for CTCz, the standard MIPS COP move-instruction
// convention) but without the extra sel operand. COP2Opnd (the generic
// 32-entry COP2 control-register operand) already exists upstream.
class CFC2OP<string asmstr, bits<5> mfmt, dag outs, dag ins> :
  InstSE<outs, ins, !strconcat(asmstr, "\t$rt, $rd"), [], FrmFR>, StdArch {
  bits<5> rt;
  bits<5> rd;
  let Inst{31-26} = 0x12;
  let Inst{25-21} = mfmt;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-0}  = 0;
}

let Predicates = [HasVU0], hasNoSchedulingInfo = 1 in {
def VU0_CFC2 : CFC2OP<"cfc2", 2, (outs GPR64Opnd:$rt), (ins COP2Opnd:$rd)>;
def VU0_CTC2 : CFC2OP<"ctc2", 6, (outs), (ins GPR64Opnd:$rt, COP2Opnd:$rd)>;
}

// Unconditional-condition-flag COP2 branches (bc2t/bc2f/bc2tl/bc2fl).
// mips-opc.c: bc2f=0x49000000, bc2fl=0x49020000, bc2t=0x49010000,
// bc2tl=0x49030000 - bits20-16 (5 bits) select between all four: the low
// bit is tf (0=false,1=true), the next is nd (0=normal,1=likely); bits
// 25-21 are a fixed 0b01000 "branch-on-C2-condition" selector, distinct
// from the CO=1 "function" format every arithmetic instruction above
// uses. Reuses the existing brtarget operand standard branches use.
class VU0_BC2_FM<bits<5> tf_nd> : StdArch {
  bits<16> offset;

  bits<32> Inst;

  let Inst{31-26} = 0x12;
  let Inst{25-21} = 0b01000;
  let Inst{20-16} = tf_nd;
  let Inst{15-0}  = offset;
}

class VU0_BC2_DESC<string opstr> :
  InstSE<(outs), (ins brtarget:$offset), !strconcat(opstr, "\t$offset"),
         [], FrmOther> {
  let Predicates = [HasVU0];
  let DecoderNamespace = "Mips";
  let hasNoSchedulingInfo = 1;
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 1;
}

let Predicates = [HasVU0] in {
def BC2F  : VU0_BC2_DESC<"bc2f">,  VU0_BC2_FM<0b00000>;
def BC2T  : VU0_BC2_DESC<"bc2t">,  VU0_BC2_FM<0b00001>;
def BC2FL : VU0_BC2_DESC<"bc2fl">, VU0_BC2_FM<0b00010>;
def BC2TL : VU0_BC2_DESC<"bc2tl">, VU0_BC2_FM<0b00011>;
}

//===----------------------------------------------------------------------===//
// lq/sq: R5900 base-ISA 128-bit GPR quadword load/store - NOT VU0/COP2 (no
// CO-bit, no COP2 major opcode); real EE hardware GPRs are natively 128
// bits wide even though the N32/N64 ABI only ever uses the low 64, and
// these instructions move the full register. Tagged "MMI" (MIPS
// Multimedia Instructions) in opcodes/mips-opc.c, not VU0 - found missing
// from upstream's own R5900 patch while porting newlib (libc/machine/
// r5900/setjmp.S uses both to save/restore full 128-bit callee-saved
// GPRs). Same base+offset shape as plain LW/SW (MipsInstrFormats.td's
// LW_FM), reusing GPR64Opnd for the register operand - clang doesn't
// need a 128-bit GPR class to encode "move the register named $s0",
// same reasoning as VU0's asm-only scope above. opcodes/mips-opc.c:
// lq=0x78000000 (op 0x1e), sq=0x7c000000 (op 0x1f).
let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1, DecoderNamespace = "R5900" in {
def LQ : InstSE<(outs GPR64Opnd:$rt), (ins mem:$addr), "lq\t$rt, $addr",
                [], FrmFI>, LW_FM<0x1e> {
  let DecoderMethod = "DecodeMem";
  let mayLoad = 1;
}
def SQ : InstSE<(outs), (ins GPR64Opnd:$rt, mem:$addr), "sq\t$rt, $addr",
                [], FrmFI>, LW_FM<0x1f> {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
}
}

// Code generation views of the MMI operations on whole 128-bit GPRs. They
// are expanded after register allocation into the P_*, LQ and SQ
// instructions, using the low 64-bit sub-register of each operand.
let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1 in {
class MMI128_3R : PseudoSE<(outs GPR128:$rd), (ins GPR128:$rs, GPR128:$rt), []>;

def PAND_128 : MMI128_3R;
def POR_128 : MMI128_3R;
def PXOR_128 : MMI128_3R;
def PNOR_128 : MMI128_3R;
def PADDB_128 : MMI128_3R;
def PADDH_128 : MMI128_3R;
def PADDW_128 : MMI128_3R;
def PSUBB_128 : MMI128_3R;
def PSUBH_128 : MMI128_3R;
def PSUBW_128 : MMI128_3R;

let mayLoad = 1 in
def LQ_128 : PseudoSE<(outs GPR128:$rt), (ins mem:$addr), []>;
let mayStore = 1 in
def SQ_128 : PseudoSE<(outs), (ins GPR128:$rt, mem:$addr), []>;
}

// di/ei (disable/enable interrupts) and sync.p: found missing, same way
// as lq/sq, while porting sdk-core's kernel.S (glue.c's DIntr/EIntr use
// di/ei directly via inline asm; kernel.h's EE_SYNCP() macro uses
// sync.p). opcodes/mips-opc.c tags the no-operand di/ei forms "EE"
// specifically (0x42000039/0x42000038 - distinct from the operand-taking
// MIPS32R2 "I33" forms at a different encoding, which upstream doesn't
// support for r5900 anyway since it's MIPS3-based); sync.p is tagged
// "I2" (MIPS II) but its encoding is a fully-fixed no-operand alias
// (0x0000040f), same shape as vnop above.
// VU0_-prefixed (not the plain DI/EI mips-opc.c uses) - upstream already
// defines DI/EI for MIPS32R2 (MipsInstrInfo.td, operand-taking GPR32
// form, different encoding); same reasoning as VU0_BC2EQZ/VU0_BC2NEZ
// earlier. Mnemonic text (what the assembler matches on) is unaffected.
let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1 in {
def VU0_DI : InstSE<(outs), (ins), "di", [], FrmOther>, StdArch {
  let Inst = 0x42000039;
}
def VU0_EI : InstSE<(outs), (ins), "ei", [], FrmOther>, StdArch {
  let Inst = 0x42000038;
}
def SYNC_P : InstSE<(outs), (ins), "sync.p", [], FrmOther>, StdArch {
  let Inst = 0x0000040f;
}
}

//===----------------------------------------------------------------------===//
// R5900 MMI (MIPS Multimedia Instructions) - the paired/packed 128-bit SIMD
// group tagged "MMI" in opcodes/mips-opc.c, plus the pipeline-1 HI/LO
// instructions (mult1/div1/madd1/mfhi1/.../mtlo1, tagged plain "EE") and the
// SA-register instructions (mfsa/mtsa/mtsab/mtsah, also "EE"). Found missing
// entirely from upstream's R5900 patch - real sdk-core code (kernel.S's
// hand-optimized memcpy/memset/strlen/strncpy) uses this group directly and
// wouldn't assemble at all before this. A much bigger gap than lq/sq/di/ei/
// sync.p (added earlier): ~100 opcodes vs. 3.
//
// Every def below is mechanically derived from the real GNU binutils EE
// build's own opcode table (toolchain/build/ee/binutils-gdb/opcodes/
// mips-opc.c) - name/args/match/mask transcribed verbatim, then the mask
// used to determine which standard R-type fields (rs[25:21], rt[20:16],
// rd[15:11], shamt[10:6]) are real operands vs. fixed constants, rather than
// hand-deriving ~100 encodings by reading the EE manual. Same GPR64Opnd
// register-operand choice as the existing lq/sq above (EE GPRs are 128 bits
// natively; MMI ops read/write the same register file, not a separate
// vector register class). Skips two purely-syntactic GNU-asm forms
// (div1/divu1's "z,s,t" mnemonic requires a literal "$0" placeholder in the
// first operand slot that doesn't correspond to any real bit - here they're
// defined as the plain 2-operand "div1 $rs, $rt" instead, same encoding,
// without replicating that print quirk) and picks the 2-operand
// s,t-only encoding for mult1/multu1/madd1/maddu1 (writes only HI1/LO1, not
// also a GPR - the simpler, more commonly used form; mips-opc.c also has a
// 3-operand d,s,t variant that additionally writes a GPR, not implemented
// here). DecoderNamespace="R5900" for the same reason as lq/sq: SPECIAL/
// SPECIAL2/REGIMM are heavily used by generic MIPS instructions this
// subtarget doesn't enable, but sharing the same decode table namespace
// risks a TableGen decode-table conflict without it.
let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1, DecoderNamespace = "R5900" in {
// Auto-generated from real GNU binutils opcodes/mips-opc.c (toolchain/build/ee/binutils-gdb).
// 102 instructions.

def P_PABSH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pabsh\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x5;
  let Inst{5-0} = 0x28;
}
def P_PABSW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pabsw\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1;
  let Inst{5-0} = 0x28;
}
def P_PADDSW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddsw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x10;
  let Inst{5-0} = 0x08;
}
def P_PADDUB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddub\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x18;
  let Inst{5-0} = 0x28;
}
def P_PADDUH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "padduh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x14;
  let Inst{5-0} = 0x28;
}
def P_PADDUW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "padduw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x10;
  let Inst{5-0} = 0x28;
}
def P_PADSBH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "padsbh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x4;
  let Inst{5-0} = 0x28;
}
def P_PAND : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pand\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x12;
  let Inst{5-0} = 0x09;
}
def P_PCEQB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pceqb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xa;
  let Inst{5-0} = 0x28;
}
def P_PCEQH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pceqh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x6;
  let Inst{5-0} = 0x28;
}
def P_PCEQW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pceqw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x2;
  let Inst{5-0} = 0x28;
}
def P_PCGTB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pcgtb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xa;
  let Inst{5-0} = 0x08;
}
def P_PCGTH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pcgth\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x6;
  let Inst{5-0} = 0x08;
}
def P_PCGTW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pcgtw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x2;
  let Inst{5-0} = 0x08;
}
def P_PCPYH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pcpyh\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1b;
  let Inst{5-0} = 0x29;
}
def P_PCPYLD : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pcpyld\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xe;
  let Inst{5-0} = 0x09;
}
def P_PCPYUD : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pcpyud\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xe;
  let Inst{5-0} = 0x29;
}
def P_PEXCH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pexch\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1a;
  let Inst{5-0} = 0x29;
}
def P_PEXCW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pexcw\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1e;
  let Inst{5-0} = 0x29;
}
def P_PEXEH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pexeh\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1a;
  let Inst{5-0} = 0x09;
}
def P_PEXEW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pexew\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1e;
  let Inst{5-0} = 0x09;
}
def P_PEXT5 : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "pext5\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1e;
  let Inst{5-0} = 0x08;
}
def P_PEXTLB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextlb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1a;
  let Inst{5-0} = 0x08;
}
def P_PEXTLH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextlh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x16;
  let Inst{5-0} = 0x08;
}
def P_PEXTLW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextlw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x12;
  let Inst{5-0} = 0x08;
}
def P_PEXTUB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextub\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1a;
  let Inst{5-0} = 0x28;
}
def P_PEXTUH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextuh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x16;
  let Inst{5-0} = 0x28;
}
def P_PEXTUW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pextuw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x12;
  let Inst{5-0} = 0x28;
}
def P_PHMADH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "phmadh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x11;
  let Inst{5-0} = 0x09;
}
def P_PHMSBH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "phmsbh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x15;
  let Inst{5-0} = 0x09;
}
def P_PINTEH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pinteh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xa;
  let Inst{5-0} = 0x29;
}
def P_PINTH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pinth\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xa;
  let Inst{5-0} = 0x09;
}
def P_PLZCW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs),
                 "plzcw\t$rd, $rs", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x04;
}
def P_PMADDH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmaddh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x10;
  let Inst{5-0} = 0x09;
}
def P_PMADDUW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmadduw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x29;
}
def P_PMADDW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmaddw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x09;
}
def P_PMAXH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmaxh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x7;
  let Inst{5-0} = 0x08;
}
def P_PMAXW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmaxw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x3;
  let Inst{5-0} = 0x08;
}
def P_PMFHI : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhi\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x8;
  let Inst{5-0} = 0x09;
}
def P_PMFHL_LH : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhl.lh\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x3;
  let Inst{5-0} = 0x30;
}
def P_PMFHL_LW : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhl.lw\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x30;
}
def P_PMFHL_SH : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhl.sh\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x4;
  let Inst{5-0} = 0x30;
}
def P_PMFHL_SLW : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhl.slw\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x2;
  let Inst{5-0} = 0x30;
}
def P_PMFHL_UW : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmfhl.uw\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1;
  let Inst{5-0} = 0x30;
}
def P_PMFLO : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "pmflo\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x9;
  let Inst{5-0} = 0x09;
}
def P_PMINH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pminh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x7;
  let Inst{5-0} = 0x28;
}
def P_PMINW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pminw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x3;
  let Inst{5-0} = 0x28;
}
def P_PMSUBH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmsubh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x14;
  let Inst{5-0} = 0x09;
}
def P_PMSUBW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmsubw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x4;
  let Inst{5-0} = 0x09;
}
def P_PMTHI : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "pmthi\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x8;
  let Inst{5-0} = 0x29;
}
def P_PMTHL_LW : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "pmthl.lw\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x31;
}
def P_PMTLO : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "pmtlo\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x9;
  let Inst{5-0} = 0x29;
}
def P_PMULTH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmulth\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1c;
  let Inst{5-0} = 0x09;
}
def P_PMULTUW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmultuw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xc;
  let Inst{5-0} = 0x29;
}
def P_PMULTW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pmultw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0xc;
  let Inst{5-0} = 0x09;
}
def P_PNOR : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pnor\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x13;
  let Inst{5-0} = 0x29;
}
def P_POR : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "por\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x12;
  let Inst{5-0} = 0x29;
}
def P_PPAC5 : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "ppac5\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1f;
  let Inst{5-0} = 0x08;
}
def P_PPACB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "ppacb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1b;
  let Inst{5-0} = 0x08;
}
def P_PPACH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "ppach\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x17;
  let Inst{5-0} = 0x08;
}
def P_PPACW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "ppacw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x13;
  let Inst{5-0} = 0x08;
}
def P_PREVH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "prevh\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1b;
  let Inst{5-0} = 0x09;
}
def P_PROT3W : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt),
                 "prot3w\t$rd, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1f;
  let Inst{5-0} = 0x09;
}
def P_PSLLVW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, GPR64Opnd:$rs),
                 "psllvw\t$rd, $rt, $rs", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x2;
  let Inst{5-0} = 0x09;
}
def P_PSRAVW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, GPR64Opnd:$rs),
                 "psravw\t$rd, $rt, $rs", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x3;
  let Inst{5-0} = 0x29;
}
def P_PSRLVW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, GPR64Opnd:$rs),
                 "psrlvw\t$rd, $rt, $rs", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x3;
  let Inst{5-0} = 0x09;
}
def P_PSUBSW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubsw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x11;
  let Inst{5-0} = 0x08;
}
def P_PSUBUB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubub\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x19;
  let Inst{5-0} = 0x28;
}
def P_PSUBUH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubuh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x15;
  let Inst{5-0} = 0x28;
}
def P_PSUBUW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubuw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x11;
  let Inst{5-0} = 0x28;
}
def P_PXOR : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "pxor\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x13;
  let Inst{5-0} = 0x09;
}
def P_QFSRV : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "qfsrv\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1b;
  let Inst{5-0} = 0x28;
}
def P_PADDB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x8;
  let Inst{5-0} = 0x08;
}
def P_PADDH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x4;
  let Inst{5-0} = 0x08;
}
def P_PADDW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x08;
}
def P_PADDSB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddsb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x18;
  let Inst{5-0} = 0x08;
}
def P_PADDSH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "paddsh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x14;
  let Inst{5-0} = 0x08;
}
def P_PSLLH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psllh\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x34;
}
def P_PSLLW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psllw\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x3c;
}
def P_PSRAH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psrah\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x37;
}
def P_PSRAW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psraw\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x3f;
}
def P_PSRLH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psrlh\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x36;
}
def P_PSRLW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rt, uimm5:$shamt),
                 "psrlw\t$rd, $rt, $shamt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rt;
  bits<5> shamt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = shamt;
  let Inst{5-0} = 0x3e;
}
def P_PSUBB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x9;
  let Inst{5-0} = 0x08;
}
def P_PSUBH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x5;
  let Inst{5-0} = 0x08;
}
def P_PSUBW : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubw\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x1;
  let Inst{5-0} = 0x08;
}
def P_PSUBSB : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubsb\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x19;
  let Inst{5-0} = 0x08;
}
def P_PSUBSH : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "psubsh\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x15;
  let Inst{5-0} = 0x08;
}
def P_MULT1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "mult1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x18;
}
def P_MULTU1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "multu1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x19;
}
def P_DIV1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "div1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x1a;
  let isAsmParserOnly = 1;
}
def P_DIVU1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "divu1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x1b;
  let isAsmParserOnly = 1;
}
def P_MADD1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "madd1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x20;
}
def P_MADDU1 : InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "maddu1\t$rs, $rt", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x21;
}
def P_MFHI1 : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "mfhi1\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x10;
}
def P_MFLO1 : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "mflo1\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x12;
}
def P_MTHI1 : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "mthi1\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x11;
}
def P_MTLO1 : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "mtlo1\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x1c;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x13;
}
def P_MFSA : InstSE<(outs GPR64Opnd:$rd), (ins),
                 "mfsa\t$rd", [], FrmOther>, StdArch {
  bits<5> rd;
  let Inst{31-26} = 0x00;
  let Inst{25-21} = 0x0;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x28;
}
def P_MTSA : InstSE<(outs), (ins GPR64Opnd:$rs),
                 "mtsa\t$rs", [], FrmOther>, StdArch {
  bits<5> rs;
  let Inst{31-26} = 0x00;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x0;
  let Inst{15-11} = 0x0;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x29;
}
def P_MTSAB : InstSE<(outs), (ins GPR64Opnd:$rs, uimm16:$imm16),
                 "mtsab\t$rs, $imm16", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<16> imm16;
  let Inst{31-26} = 0x01;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x18;
  let Inst{15-0} = imm16;
}
def P_MTSAH : InstSE<(outs), (ins GPR64Opnd:$rs, uimm16:$imm16),
                 "mtsah\t$rs, $imm16", [], FrmOther>, StdArch {
  bits<5> rs;
  bits<16> imm16;
  let Inst{31-26} = 0x01;
  let Inst{25-21} = rs;
  let Inst{20-16} = 0x19;
  let Inst{15-0} = imm16;
}
def P_MOVN : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "movn\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x0;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x0b;
}
def P_MOVZ : InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
                 "movz\t$rd, $rs, $rt", [], FrmOther>, StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{31-26} = 0x0;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0x0;
  let Inst{5-0} = 0x0a;
}
}

//===----------------------------------------------------------------------===//
// cache/pref - found missing on the IOP side while porting sdk-core's
// sysclib (newlib's hand-optimized mips/memset.S etc use pref for
// prefetch hints). Upstream's own CACHE/PREF (MipsInstrInfo.td) exist but
// are gated behind INSN_MIPS3_32_NOT_32R6_64R6, which pulls in real
// FeatureMips3_32 - a genuine MIPS III/32 instruction-selection feature,
// not just "these two mnemonics are legal here". Reusing the real
// encoding (CacheOp/CACHEOP_FM, both already upstream) under our own
// FeaturePS2Cache instead keeps the IOP's mips1 codegen baseline
// untouched - this predicate only ever affects whether cache/pref parse,
// nothing about what the compiler itself chooses to emit. FeatureR5900
// implies it too, closing the EE-side gap the README flagged as
// unresolved ("cache fails... despite the predicate chain looking
// satisfied on paper" - HasStdEnc, not FeatureMips3_32, was blocking
// upstream's own CACHE/PREF; irrelevant to these, which don't use it).
let Predicates = [HasPS2CachePred], hasNoSchedulingInfo = 1,
    DecoderNamespace = "R5900" in {
def P2_CACHE : CacheOp<"cache", mem>, CACHEOP_FM<0b101111>;
def P2_PREF  : CacheOp<"pref", mem>, CACHEOP_FM<0b110011>;
}

//===----------------------------------------------------------------------===//
// sync.l: found missing while porting sdk-core's core/dma (kernel.h's
// EE_SYNCL() macro). Same shape as sync.p above - opcodes/mips-opc.c
// tags it "I2" with a fully-fixed no-operand encoding (0x0000000f, the
// same bits as plain "sync" with stype=0xf), so it's a real fixed-
// encoding mnemonic alias, not a new instruction.
let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1 in {
def SYNC_L : InstSE<(outs), (ins), "sync.l", [], FrmOther>, StdArch {
  let Inst = 0x0000000f;
}
}

//===----------------------------------------------------------------------===//
// bc0f/bc0t/bc0fl/bc0tl: found missing, same file (core/dma's polling
// loop branches on COP0's condition bit). No upstream LLVM MIPS support
// exists for any COP0 conditional branch. Same shape as VU0_BC2_DESC/
// VU0_BC2_FM above (real, already-upstream BC2F/BC2T/BC2FL/BC2TL) - COP0
// (major opcode 0x10) instead of COP2 (0x12), same BC sub-format
// (bits 25-21 = 0b01000) and tf_nd encoding (00=f, 01=t, 10=fl, 11=tl).
// opcodes/mips-opc.c: bc0f=0x41000000, bc0t=0x41010000, bc0fl=0x41020000,
// bc0tl=0x41030000, mask 0xffff0000.
class BC0_FM<bits<5> tf_nd> : StdArch {
  bits<16> offset;

  bits<32> Inst;

  let Inst{31-26} = 0x10;
  let Inst{25-21} = 0b01000;
  let Inst{20-16} = tf_nd;
  let Inst{15-0}  = offset;
}

class BC0_DESC<string opstr> :
  InstSE<(outs), (ins brtarget:$offset), !strconcat(opstr, "\t$offset"),
         [], FrmOther> {
  let Predicates = [IsR5900Pred];
  let DecoderNamespace = "R5900";
  let hasNoSchedulingInfo = 1;
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 1;
}

let Predicates = [IsR5900Pred] in {
def BC0F  : BC0_DESC<"bc0f">,  BC0_FM<0b00000>;
def BC0T  : BC0_DESC<"bc0t">,  BC0_FM<0b00001>;
def BC0FL : BC0_DESC<"bc0fl">, BC0_FM<0b00010>;
def BC0TL : BC0_DESC<"bc0tl">, BC0_FM<0b00011>;
}

//===----------------------------------------------------------------------===//
// slt/sltu 2-operand register form: found missing while porting sdk-core's
// kernel.S (its cache-sync macros compare TLB entries via "sltu $2, $4",
// real GNU as's 2-operand shorthand for "sltu $2, $2, $4"). Every other
// ArithLogicR-based R-type ALU op (and/or/xor/add/addu/sub/subu) gets this
// shorthand for free from upstream's own TwoOperandAliasConstraint on that
// class (MipsInstrInfo.td) - SLT/SLTu use the separate SetCC_R class
// instead, which never got the same constraint. A real, general upstream
// gap (not R5900-specific), scoped here rather than touched on the shared
// class to stay minimal.
def : MipsInstAlias<"slt $rs, $rt",
                     (SLT GPR32Opnd:$rs, GPR32Opnd:$rs, GPR32Opnd:$rt), 0>;
def : MipsInstAlias<"sltu $rs, $rt",
                     (SLTu GPR32Opnd:$rs, GPR32Opnd:$rs, GPR32Opnd:$rt), 0>;

//===----------------------------------------------------------------------===//
// EE hardware-breakpoint COP0 register moves: found missing while porting
// sdk-core's eedebug/debug packages (ee_dbg_low.S, ee_exceptions.S,
// hwbp.S - real hardware watchpoint setup/readback, mf/mt x bpc/iab/iabm/
// dab/dabm/dvb/dvbm, 14 instructions total). opcodes/mips-opc.c: single
// GPR operand each, mask 0xffe0ffff (only rt, bits20-16, varies) -
// mfbpc=0x4000c000, mfiab=0x4000c002, mfiabm=0x4000c003, mfdab=0x4000c004,
// mfdabm=0x4000c005, mfdvb=0x4000c006, mfdvbm=0x4000c007; mt-family is the
// same low 16 bits with bits31-21 0x404 instead of mf's 0x400.
class EEDBG_FM<bits<11> hi, bits<16> lo> : StdArch {
  bits<5> rt;

  bits<32> Inst;

  let Inst{31-21} = hi;
  let Inst{20-16} = rt;
  let Inst{15-0}  = lo;
}

class EEDBG_DESC<string opstr> :
  InstSE<(outs GPR32Opnd:$rt), (ins), !strconcat(opstr, "\t$rt"), [],
         FrmOther> {
  let Predicates = [IsR5900Pred];
  let DecoderNamespace = "R5900";
  let hasNoSchedulingInfo = 1;
}

class EEDBG_W_DESC<string opstr> :
  InstSE<(outs), (ins GPR32Opnd:$rt), !strconcat(opstr, "\t$rt"), [],
         FrmOther> {
  let Predicates = [IsR5900Pred];
  let DecoderNamespace = "R5900";
  let hasNoSchedulingInfo = 1;
}

let Predicates = [IsR5900Pred] in {
def MFBPC  : EEDBG_DESC<"mfbpc">,  EEDBG_FM<0x200, 0xc000>;
def MFIAB  : EEDBG_DESC<"mfiab">,  EEDBG_FM<0x200, 0xc002>;
def MFIABM : EEDBG_DESC<"mfiabm">, EEDBG_FM<0x200, 0xc003>;
def MFDAB  : EEDBG_DESC<"mfdab">,  EEDBG_FM<0x200, 0xc004>;
def MFDABM : EEDBG_DESC<"mfdabm">, EEDBG_FM<0x200, 0xc005>;
def MFDVB  : EEDBG_DESC<"mfdvb">,  EEDBG_FM<0x200, 0xc006>;
def MFDVBM : EEDBG_DESC<"mfdvbm">, EEDBG_FM<0x200, 0xc007>;

def MTBPC  : EEDBG_W_DESC<"mtbpc">,  EEDBG_FM<0x204, 0xc000>;
def MTIAB  : EEDBG_W_DESC<"mtiab">,  EEDBG_FM<0x204, 0xc002>;
def MTIABM : EEDBG_W_DESC<"mtiabm">, EEDBG_FM<0x204, 0xc003>;
def MTDAB  : EEDBG_W_DESC<"mtdab">,  EEDBG_FM<0x204, 0xc004>;
def MTDABM : EEDBG_W_DESC<"mtdabm">, EEDBG_FM<0x204, 0xc005>;
def MTDVB  : EEDBG_W_DESC<"mtdvb">,  EEDBG_FM<0x204, 0xc006>;
def MTDVBM : EEDBG_W_DESC<"mtdvbm">, EEDBG_FM<0x204, 0xc007>;
}

//===----------------------------------------------------------------------===//
// R5900 multiply/divide forms with a destination register or a literal $0.
// mips-opc.c lists "d,s,t" variants of mult/multu/madd/maddu and of the
// pipeline-1 versions that also write a GPR, plain two-operand madd/maddu
// (the R5900 has no generic MIPS32 ISA bit, so the base definitions never
// apply), and div1/divu1 spelled "z,s,t" with a literal $0 first operand.
//===----------------------------------------------------------------------===//
class R5900_RSRT_FM<bits<6> major, bits<6> funct> : StdArch {
  bits<5> rs;
  bits<5> rt;
  bits<32> Inst;
  let Inst{31-26} = major;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = 0;
  let Inst{10-6} = 0;
  let Inst{5-0} = funct;
}

class R5900_RDRSRT_FM<bits<6> major, bits<6> funct> : StdArch {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  bits<32> Inst;
  let Inst{31-26} = major;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = rd;
  let Inst{10-6} = 0;
  let Inst{5-0} = funct;
}

class R5900_ZRSRT_FM<bits<6> major, bits<6> funct> : StdArch {
  bits<5> z;
  bits<5> rs;
  bits<5> rt;
  bits<32> Inst;
  let Inst{31-26} = major;
  let Inst{25-21} = rs;
  let Inst{20-16} = rt;
  let Inst{15-11} = z;
  let Inst{10-6} = 0;
  let Inst{5-0} = funct;
}

class R5900_MULDIV2<string opstr> :
  InstSE<(outs), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
         !strconcat(opstr, "\t$rs, $rt"), [], FrmOther>;
class R5900_MULDIV3<string opstr> :
  InstSE<(outs GPR64Opnd:$rd), (ins GPR64Opnd:$rs, GPR64Opnd:$rt),
         !strconcat(opstr, "\t$rd, $rs, $rt"), [], FrmOther>;
class R5900_DIVZ<string opstr> :
  InstSE<(outs), (ins GPR32ZeroOpnd:$z, GPR64Opnd:$rs, GPR64Opnd:$rt),
         !strconcat(opstr, "\t$z, $rs, $rt"), [], FrmOther>;

let Predicates = [IsR5900Pred], hasNoSchedulingInfo = 1,
    DecoderNamespace = "R5900" in {
def P_MADD    : R5900_MULDIV2<"madd">,   R5900_RSRT_FM<0x1c, 0x00>;
def P_MADDU   : R5900_MULDIV2<"maddu">,  R5900_RSRT_FM<0x1c, 0x01>;
def P_MADD3   : R5900_MULDIV3<"madd">,   R5900_RDRSRT_FM<0x1c, 0x00>;
def P_MADDU3  : R5900_MULDIV3<"maddu">,  R5900_RDRSRT_FM<0x1c, 0x01>;
def P_MADD1_3 : R5900_MULDIV3<"madd1">,  R5900_RDRSRT_FM<0x1c, 0x20>;
def P_MADDU1_3: R5900_MULDIV3<"maddu1">, R5900_RDRSRT_FM<0x1c, 0x21>;
def P_MULT1_3 : R5900_MULDIV3<"mult1">,  R5900_RDRSRT_FM<0x1c, 0x18>;
def P_MULTU1_3: R5900_MULDIV3<"multu1">, R5900_RDRSRT_FM<0x1c, 0x19>;
let DecoderMethod = "DecodeR5900MulRd" in {
def P_MULT3   : R5900_MULDIV3<"mult">,   R5900_RDRSRT_FM<0x00, 0x18>;
def P_MULTU3  : R5900_MULDIV3<"multu">,  R5900_RDRSRT_FM<0x00, 0x19>;
}
let Defs = [HI0, LO0], isCodeGenOnly = 1,
    AddedComplexity = 10 in
def MUL_R5900 : ArithLogicR<"mult", GPR32Opnd, 1, mul>,
                R5900_RDRSRT_FM<0x00, 0x18>;
def P_DIV1_Z  : R5900_DIVZ<"div1">,      R5900_ZRSRT_FM<0x1c, 0x1a>;
def P_DIVU1_Z : R5900_DIVZ<"divu1">,     R5900_ZRSRT_FM<0x1c, 0x1b>;
}
