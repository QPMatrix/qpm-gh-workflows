#!/bin/sh
# Vendors qpsb-agents' agents/claude/*.md at a pinned commit into
# .cache/qpsb-agents. The pin below is WRITTEN by a tool, never
# hand-typed: repo-birth's birth.py (resolved live via `git ls-remote`
# at birth) or repo-instructions' `instructions.py wire-gate` /
# `sync --qp-agents-ref` afterwards (QPMSEC-475 B3). Same
# clone-at-a-pin shape as scripts/qp-skills-fetch.sh — clone, then
# `checkout --detach <ref>`, so a commit SHA pins exactly like a branch
# name does (QPMSEC-475 L2). Template: qpsb-skills
# skills/repo-instructions/references/qp-agents-fetch.sh.template —
# one fetch mechanism per pinned estate dependency, shared not copied
# (code-craft rule 7). This repo's own gate runs this before
# instructions.py check --require-sources (repo-instructions skill,
# QPMSEC-436 review round 2, findings 2/4) — no laptop-only stand-in
# path can ever satisfy CI, so CI must always reach real content here.
#
# Usage:
#   sh scripts/qp-agents-fetch.sh
set -eu

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_PREFIX

QP_AGENTS_REF="${QP_AGENTS_REF:-eab8a285a6720ab92a7ccebc6122d633a9c7905a}"
QP_AGENTS_REPO="${QP_AGENTS_REPO:-https://github.com/QPMatrix/qpsb-agents}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${QP_AGENTS_CACHE_DIR:-$REPO_ROOT/.cache/qpsb-agents}"

echo "==> Fetching qpsb-agents @ $QP_AGENTS_REF"
if [ -d "$CACHE_DIR/.git" ]; then
  git -C "$CACHE_DIR" fetch --quiet origin "$QP_AGENTS_REF"
else
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --quiet "$QP_AGENTS_REPO" "$CACHE_DIR"
fi
git -C "$CACHE_DIR" checkout --quiet --detach "$QP_AGENTS_REF"

resolved_sha="$(git -C "$CACHE_DIR" rev-parse HEAD)"
echo "==> Vendored qpsb-agents@$resolved_sha into .cache/qpsb-agents"

# Write the SAME .source marker shape instructions.py's own fetch_qp_agents()
# writes on its git path (git:<repo>@<sha>) — instructions.py check reads
# this file to render/compare "Agents mounted (pinned at qpsb-agents@...)";
# without it a repo whose gate fetches via THIS script (rather than via
# `instructions.py sync`) would always show as "unknown" and never match
# what sync originally committed. $QP_AGENTS_REPO here is the plain
# CONFIGURED url (never a token-rewritten one — this script never reads
# back `git remote get-url origin`, which could carry an injected
# credential from a CI insteadOf rewrite; secrets-and-tenancy: names/URLs
# only, never a token value).
echo "git:$QP_AGENTS_REPO@$resolved_sha" > "$CACHE_DIR/.source"
