#!/bin/sh
# Vendors skills and agents from qpai-skills at a pinned commit into .cache/qpai-skills. The pin
# below is WRITTEN by a tool, never hand-typed: repo-birth's birth.py
# (resolved live via `git ls-remote` at birth) or repo-instructions'
# `instructions.py wire-gate` / `sync --qp-skills-ref` afterwards
# (QPMSEC-475 B3: the tool owns the bump; INSTRUCTIONS.md's recorded
# pin is derived from THIS script's checkout, never the reverse).
# Template: qpai-skills skills/repo-instructions/references/
# qp-skills-fetch.sh.template — one fetch mechanism per pinned estate
# dependency, shared not copied (code-craft rule 7). This repo's own
# gate runs this before instructions.py check (repo-instructions
# skill, QPMSEC-436).
#
# Usage:
#   sh scripts/qp-skills-fetch.sh
set -eu

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_PREFIX

QP_SKILLS_REF="${QP_SKILLS_REF:-29a924f5a339852a041e006a3625f518005078a6}"
QP_SKILLS_REPO="${QP_SKILLS_REPO:-https://github.com/QPMatrix/qpai-skills}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${QP_SKILLS_CACHE_DIR:-$REPO_ROOT/.cache/qpai-skills}"

echo "==> Fetching qpai-skills @ $QP_SKILLS_REF"
if [ -d "$CACHE_DIR/.git" ]; then
  git -C "$CACHE_DIR" fetch --quiet origin "$QP_SKILLS_REF"
else
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --quiet "$QP_SKILLS_REPO" "$CACHE_DIR"
fi
git -C "$CACHE_DIR" checkout --quiet --detach "$QP_SKILLS_REF"

resolved_sha="$(git -C "$CACHE_DIR" rev-parse HEAD)"
echo "==> Vendored qpai-skills@$resolved_sha into .cache/qpai-skills"
