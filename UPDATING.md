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
