#!/bin/sh
# verify-git-auth-insteadof.sh — network-free proof that the three git
# `insteadOf` rules every "Configure git auth for QPMatrix" step applies
# (https, `ssh://`, and the scp-like `git@` form) all rewrite to the
# SAME https+token target. `git ls-remote --get-url <url>` prints the
# URL `insteadOf` rewrites it to WITHOUT touching the network — git
# resolves `insteadOf` purely from config before it would ever open a
# connection — so this proves the rewrite the same way a real
# `git clone`/`bun install` would apply it, with no remote involved and
# no real token.
#
# Reproduces the defect fixed 2026-09-16: qpai-core's private git
# dependency was spelled `git+ssh://git@github.com/QPMatrix/<repo>.git`
# in package.json. Bun resolves a `git+ssh` dependency by trying an
# https clone first and the ssh form second; an https-only `insteadOf`
# rule rewrites the first attempt (which then failed anyway —
# `remote: Invalid username or token` — because that first attempt was
# STILL unauthenticated in the reproduction that isolated this bug) and
# leaves the ssh-form attempt unrewritten, so it falls through to a real
# ssh clone and fails `Permission denied (publickey)` (no key configured
# on the runner). This script asserts all three forms rewrite
# identically, the way ts-gate.yml/go-gate.yml/rust-gate.yml/
# python-gate.yml/check-gate.yml/ci.yml's "Configure git auth for
# QPMatrix" step now does.
#
# `GIT_CONFIG_GLOBAL` points git at a throwaway file instead of the
# real `~/.gitconfig` — never `git config --global` against the real
# one — set to exactly the three lines each "Configure git auth for
# QPMatrix" step runs.
set -eu

token="test-token-not-real"
target="https://x-access-token:${token}@github.com/QPMatrix/"

GIT_CONFIG_GLOBAL=$(mktemp)
export GIT_CONFIG_GLOBAL
trap 'rm -f "$GIT_CONFIG_GLOBAL"' EXIT

git config --global url."${target}".insteadOf "https://github.com/QPMatrix/"
git config --global --add url."${target}".insteadOf "ssh://git@github.com/QPMatrix/"
git config --global --add url."${target}".insteadOf "git@github.com:QPMatrix/"

expected="${target}x.git"

assert_rewrite() {
  form="$1"
  input="$2"
  actual=$(git ls-remote --get-url "$input")
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: ${form} form '${input}' rewrote to '${actual}', expected '${expected}'" >&2
    exit 1
  fi
  echo "OK: ${form} form '${input}' -> ${actual}"
}

assert_rewrite "https"    "https://github.com/QPMatrix/x.git"
assert_rewrite "ssh://"   "ssh://git@github.com/QPMatrix/x.git"
assert_rewrite "scp-like" "git@github.com:QPMatrix/x.git"

echo "verify-git-auth-insteadof.sh: all three URL forms rewrite to the same target"
