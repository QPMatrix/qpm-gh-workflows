#!/bin/sh
# Installs a pinned, checksum-verified `actionlint` binary (QPMSEC-570
# round-2 review finding 2: this repo's own CI must actually run
# actionlint over every workflow file it ships — ./check calls this
# script, then runs `actionlint`, so hook = CI = this file (repo-gates-
# and-hooks rule 4) covers it too).
#
# Usage:
#   sh scripts/install-actionlint.sh
#
# Idempotent: a matching pinned version already on PATH at $BIN_DIR is a
# no-op with exit 0.
#
# Requires: curl, tar, and sha256sum or shasum, on PATH.
set -eu

ACTIONLINT_VERSION="1.7.12"  # verified via
  # `gh api repos/rhysd/actionlint/releases/latest --jq .tag_name` on
  # 2026-09-03 (repo-gates-and-hooks rule 8).

BIN_DIR="${ACTIONLINT_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

need_install=1
if command -v "$BIN_DIR/actionlint" >/dev/null 2>&1; then
  current_version="$("$BIN_DIR/actionlint" -version | head -1 | awk '{print $1}')"
  if [ "$current_version" = "$ACTIONLINT_VERSION" ]; then
    echo "--> actionlint $ACTIONLINT_VERSION already installed at $BIN_DIR/actionlint"
    need_install=0
  fi
fi

if [ "$need_install" -eq 1 ]; then
  echo "--> actionlint $ACTIONLINT_VERSION"
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Darwin) al_os="darwin" ;;
    Linux) al_os="linux" ;;
    *) echo "error: unsupported OS for actionlint download: $os" >&2; exit 1 ;;
  esac
  case "$arch" in
    arm64|aarch64) al_arch="arm64" ;;
    x86_64|amd64) al_arch="amd64" ;;
    *) echo "error: unsupported architecture for actionlint download: $arch" >&2; exit 1 ;;
  esac

  asset="actionlint_${ACTIONLINT_VERSION}_${al_os}_${al_arch}.tar.gz"
  base_url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}"

  echo "    downloading $base_url/$asset"
  curl -sSL -o "$WORK_DIR/$asset" "$base_url/$asset"
  curl -sSL -o "$WORK_DIR/checksums.txt" "$base_url/actionlint_${ACTIONLINT_VERSION}_checksums.txt"

  expected_line="$(grep " ${asset}\$" "$WORK_DIR/checksums.txt" || true)"
  if [ -z "$expected_line" ]; then
    echo "error: no checksums.txt entry for $asset (actionlint $ACTIONLINT_VERSION release)" >&2
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$WORK_DIR" && echo "$expected_line" | sha256sum -c - ) \
      || { echo "error: actionlint archive failed sha256 verification" >&2; exit 1; }
  elif command -v shasum >/dev/null 2>&1; then
    ( cd "$WORK_DIR" && echo "$expected_line" | shasum -a 256 -c - ) \
      || { echo "error: actionlint archive failed sha256 verification" >&2; exit 1; }
  else
    echo "error: need sha256sum or shasum on PATH to verify the actionlint download" >&2
    exit 1
  fi

  tar -xzf "$WORK_DIR/$asset" -C "$WORK_DIR" actionlint
  cp "$WORK_DIR/actionlint" "$BIN_DIR/actionlint"
  chmod +x "$BIN_DIR/actionlint"
fi

echo "==> Done. Ensure $BIN_DIR is on PATH before running 'actionlint'."
