#!/bin/sh
# find-latest-tag.sh — prints the latest v[0-9]* tag reachable from HEAD
# in the current working directory's git repo, or FAILs loud on stderr
# and exits 1 when the repo carries no v* tag at all (spec
# 002-versioned-auto-deploy's plan.md D1 point 2: never guess v0.1.0 —
# that guess belongs to the one-time seeding task, T-002, not to a
# workflow that runs on every merge).
#
# semver-tag.yml embeds this EXACT logic inline between the
# "BEGIN find-latest-tag"/"END find-latest-tag" markers (D1a — see
# classify-bump.sh's header for why the production copy can't just
# `source` this file). THIS file is the single source of truth;
# self-test.yml's `semver-tag-inline-sync-selftest` job diffs the two
# copies so they can never silently drift.
set -eu

# BEGIN find-latest-tag
latest_tag=$(git tag -l 'v*' --sort=-v:refname | head -1)

if [ -z "$latest_tag" ]; then
  echo "FAIL: no v* tag reachable from HEAD — semver-tag.yml never guesses a baseline (seed one first, spec 002-versioned-auto-deploy T-002)." >&2
  exit 1
fi

echo "$latest_tag"
# END find-latest-tag
