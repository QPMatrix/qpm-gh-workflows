#!/bin/sh
# guard-primary-worktree.sh — QPMSEC-389: refuse a commit on a seat
# branch (task/*) made directly in a repo's PRIMARY checkout instead of
# a worktree.sh tree.
#
# WHY: on QPMSEC-209 a seat's scope was revised mid-task to a SECOND
# repo (qp-skills). It never ran `worktree.sh worker` for that repo and
# committed straight into the SHARED checkout at
# .../qpm-secondbrain/qp-skills, on branch task/QPMSEC-209 — the
# owner's own working tree silently became a seat's workspace while a
# second seat (QPMSEC-387) worked the SAME repo, at the SAME time, in
# its own correctly-isolated worktree. worktree.sh was already fully
# generic for a second repo — `worker <repo-path> <branch> <dest>` has
# no baked-in paths, repo and dest are plain arguments — so there was
# no missing CAPABILITY. What was missing was ENFORCEMENT: nothing
# stopped `git commit` from succeeding in the wrong tree. This script
# is that stop.
#
# THE SIGNAL — a seat-shaped commit in a PRIMARY worktree, deliberately
# narrow so it never touches the owner's own hand-typed work:
#   1. PRIMARY, not linked: `git rev-parse --git-dir` resolves to the
#      same directory as `--git-common-dir`. A worktree.sh tree (worker
#      OR review mode) is always a LINKED worktree — git-dir lives
#      under <repo>/.git/worktrees/<name>, common-dir stays the shared
#      .git — so every correctly-dispatched seat is exempt outright,
#      by construction, never by an allowlist.
#   2. Branch matches `task/*` — reserved exclusively for worktree.sh's
#      own branch convention (verified by grepping every skill and
#      every dispatch contract in this estate on 2026-08-23: the only
#      "task/" branch-name occurrences are worker-dispatch's own
#      worktree.sh callers and this skill's tests). The owner's manual
#      work lives on differently-named branches (fix/*, chore/*, a
#      feature name, or main directly) and is never touched by this
#      guard — this is the boundary that keeps the guard from blocking
#      legitimate hand-typed commits (the trap QPMSEC-389 named
#      explicitly).
# Both conditions must hold. A commit on task/* in a LINKED worktree
# passes (that is the normal, correct seat workflow). A commit on any
# OTHER branch in the PRIMARY checkout passes (that is the owner). Only
# the intersection — PRIMARY + task/* — is refused.
#
# HONEST LIMIT: like every other hook in this estate, this is enforced
# at commit time, not made physically impossible — `git commit
# --no-verify` still bypasses it at the git level. repo-gates-and-hooks
# rule 5 already treats `--no-verify` as "not a tool this estate uses"
# and a bypass found in history as a review finding; this guard adds no
# new gap, it inherits the estate's existing bypass posture rather than
# inventing a stronger one that doesn't exist anywhere else either.
#
# INSTALL: committed once per repo at .githooks/guard-primary-worktree.sh
# (copied verbatim from THIS file — qpsb-skills
# skills/worker-dispatch/scripts/guard-primary-worktree.sh is the single
# source of truth, code-craft rule 7's documented-denormalization
# exception; no cross-repo script-sourcing convention exists in this
# estate, so a byte-identical copy is how every repo's hook already
# carries its own gate logic — same pattern as qp-api's hook commenting
# "mirrors qpm-go-service's own hook"). `.githooks/pre-commit` calls it
# before the repo's own gate:
#   sh "$(dirname "$0")/guard-primary-worktree.sh" || exit 1
# `birth.py` seeds this automatically for every new repo (reads this
# file at birth time — never hand-copies stale text). Existing repos
# need the same two-line addition to their `.githooks/pre-commit`; see
# repo-gates-and-hooks SKILL.md, "Primary-worktree guard rollout".
#
# NOT wired into CI (repo-gates-and-hooks rule 4, "hook ⊆ CI", does not
# apply here): CI always runs on a fresh, single-purpose runner clone —
# it is NEVER a "primary checkout" in the sense this guard means (no
# worktree.sh tree competes with it, no owner works in it by hand), so
# the invariant this guard protects has no CI equivalent to mirror.
#
# Usage: guard-primary-worktree.sh   (no args; run from inside the tree
# being committed to, e.g. from a pre-commit hook — reads git state via
# `git rev-parse`/`git symbolic-ref`, does not touch the working tree)
# Exit 0 = commit allowed (linked worktree, or non-task/* branch).
# Exit 1 = refused (primary checkout, HEAD on a task/* branch).
set -eu

GIT_DIR=$(git rev-parse --git-dir)
COMMON_DIR=$(git rev-parse --git-common-dir)
GIT_DIR_ABS=$(CDPATH='' cd -- "$GIT_DIR" && pwd)
COMMON_DIR_ABS=$(CDPATH='' cd -- "$COMMON_DIR" && pwd)

if [ "$GIT_DIR_ABS" != "$COMMON_DIR_ABS" ]; then
  # Linked worktree — worktree.sh's own trees always look like this.
  # Never the shared checkout; always exempt.
  exit 0
fi

BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
case "$BRANCH" in
  task/*)
    echo "guard-primary-worktree: refused." >&2
    echo "  This is the PRIMARY checkout (git-dir == git-common-dir)," >&2
    echo "  and HEAD is on '$BRANCH' — a branch name reserved for" >&2
    echo "  worktree.sh trees, never committed to directly here." >&2
    echo "  Give this branch its own tree instead:" >&2
    echo "    skills/worker-dispatch/scripts/worktree.sh worker <repo-path> $BRANCH <dest>" >&2
    echo "  (QPMSEC-389 — see worker-dispatch SKILL.md)" >&2
    exit 1
    ;;
esac
exit 0
