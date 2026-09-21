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

## Updating the published copy (this repo)

r5900-ee lives in the full local clone with real upstream history behind
it. This repo is a stripped copy of the same 3 commits with a fake root
instead of ~600k commits of LLVM history, so it can't just be pushed
straight from r5900-ee after a rebase - the root has to move too, since
its tree is the new base commit's tree.

    NEWROOT=$(git commit-tree <upstream-commit>^{tree} -m "base")
    git rebase --onto $NEWROOT <old-root-commit> r5900-ee-publish
    git push --force ps2-fork r5900-ee-publish:main
