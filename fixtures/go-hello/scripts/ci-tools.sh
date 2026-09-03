#!/bin/sh
# go-gate.yml self-test fixture's tool hook (QPMSEC-570 round 7): proves
# the reusable workflow actually finds and runs scripts/ci-tools.sh,
# BEFORE any stage, in every job that runs one. Installs one trivial,
# harmless marker "tool" — real repos install real ones here (buf, the
# protoc plugins, ...); the calling workflow step (not this script, same
# convention as scripts/install-buf.sh) adds $HOME/.local/bin to
# $GITHUB_PATH afterward.
set -eu

BIN_DIR="${CI_TOOLS_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/qpmsec570-ci-tools-marker" <<'EOF'
#!/bin/sh
echo "qpmsec570-ci-tools-marker: scripts/ci-tools.sh ran before this stage"
EOF
chmod +x "$BIN_DIR/qpmsec570-ci-tools-marker"

echo "==> Done. qpmsec570-ci-tools-marker installed at $BIN_DIR."
