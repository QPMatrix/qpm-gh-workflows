#!/bin/sh
# classify-bump.sh — reads full commit messages (subject + body, one per
# commit) from stdin and prints the highest semver bump found: major,
# minor, patch, or none. Conventional Commits header grammar
# (<type>[optional scope][!]: <description>) plus a BREAKING CHANGE:/
# BREAKING-CHANGE: footer anywhere in the body — exactly spec
# 002-versioned-auto-deploy's plan.md D1 point 3's classification. No
# commits on stdin (tag == HEAD) -> "none".
#
# Input shape: commits separated by a line holding exactly the sentinel
# "@@QPM-COMMIT-BOUNDARY@@" — the same shape
# `git log <tag>..HEAD --format='%B@@QPM-COMMIT-BOUNDARY@@'` produces,
# one block per commit, git's own trailing newline between commits acting
# as ordinary blank-line content inside a block (harmless to the grep
# checks below, which only care about line starts).
#
# The `newline=$(printf '\nx'); newline=${newline%x}` idiom builds a
# one-character newline value portably (command substitution strips
# TRAILING newlines only, so the guard "x" protects it) instead of a
# literal source-code line break inside the string concatenation below —
# a literal break would carry whatever leading indentation the SOURCE
# LINE happens to sit at into the accumulated commit body, which is fine
# here at column 0 but corrupts the reconstructed body the moment this
# exact text is re-indented (semver-tag.yml embeds it nested inside a
# `run: |` block several levels deep — see below).
#
# semver-tag.yml embeds this EXACT logic inline between the
# "BEGIN classify-bump"/"END classify-bump" markers (D1a: the running
# workflow is inline shell only — a caller repo's checkout never contains
# this repo's own scripts/, so the production copy cannot be `source`d
# from here). THIS file is the single source of truth; self-test.yml's
# `semver-tag-inline-sync-selftest` job diffs the marked block in
# semver-tag.yml against this file's own marked block so the two copies
# can never silently drift (code-craft rule 7 — a duplication that must
# stay, reconciled by an automated check, not a shrug). Test coverage
# (the four bump classes) always runs against THIS file directly.
set -eu

# BEGIN classify-bump
highest="none"
highest_rank=0
buffer=""
newline=$(printf '\nx')
newline=${newline%x}

rank_of() {
  case "$1" in
    major) echo 3 ;;
    minor) echo 2 ;;
    patch) echo 1 ;;
    *) echo 0 ;;
  esac
}

classify_commit() {
  msg="$1"
  [ -z "$msg" ] && return 0
  subject=$(printf '%s\n' "$msg" | head -1)
  this="none"
  if printf '%s\n' "$msg" | grep -qE '^(BREAKING CHANGE|BREAKING-CHANGE):'; then
    this="major"
  elif printf '%s\n' "$subject" | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:'; then
    this="major"
  elif printf '%s\n' "$subject" | grep -qE '^feat(\([^)]*\))?:'; then
    this="minor"
  elif printf '%s\n' "$subject" | grep -qE '^fix(\([^)]*\))?:'; then
    this="patch"
  fi
  this_rank=$(rank_of "$this")
  if [ "$this_rank" -gt "$highest_rank" ]; then
    highest="$this"
    highest_rank="$this_rank"
  fi
}

while IFS= read -r line; do
  if [ "$line" = "@@QPM-COMMIT-BOUNDARY@@" ]; then
    classify_commit "$buffer"
    buffer=""
  elif [ -z "$buffer" ]; then
    buffer="$line"
  else
    buffer="$buffer$newline$line"
  fi
done
classify_commit "$buffer"

echo "$highest"
# END classify-bump
