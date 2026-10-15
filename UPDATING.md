# Updating this branch from upstream

Don't track upstream continuously. R5900 is dead hardware, nothing new is
coming, so there's no reason to chase every LLVM release. Rebase only when
you actually need something from a newer base.

    git fetch origin
    git rebase <upstream-commit> r5900-ee

Conflicts, if any, are almost always in Mips.td or MipsInstrInfo.td.

Before trusting the result, rebuild and rerun the checks:

    llvm/rebuild_phase2.bat
    scratch/llvm-mmi-test    (make, run in PCSX2, expect 22/22 PASS)
    scratch/llvm-makefile-test    (make, run in PCSX2)

## Pushing to the private remote

git.techwritescode.dev/ps2/llvm is a real migrated copy of llvm/llvm-project,
not a squashed history - main tracks upstream, r5900-ee carries our commits
on top. After a rebase:

    git push ps2-fork main            # keep main in sync with upstream
    git push --force ps2-fork r5900-ee

## What belongs in the fork

Only changes specific to the PS2 CPUs:

- Target code gated on the R5900 or R3000A: subtarget features, `isR5900()`/`isR3000A()`, scheduling models,
  instruction definitions and selection.
- Runtime code gated on `__ps2sdk__` or `_MIPS_ARCH_R5900`.
- Hidden `cl::opt` switches that default to off.

Not in the fork: edits to generic passes or `TargetTransformInfo.h`, pass-pipeline callbacks that add
optimisation passes, clang driver changes to what `-O1`/`-O2` mean, and thresholds or counts tuned to a benchmark.
A speed gap that a hardware fact (latency, cost, instruction) cannot close is documented as an exception instead.
