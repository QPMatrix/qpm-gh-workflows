#!/bin/sh
# bump-version.sh <current-tag> <bump> — prints the next vX.Y.Z tag name
# given the current tag (vX.Y.Z, leading v mandatory) and a bump class
# (major|minor|patch — "none" is never passed here, the caller skips
# tagging entirely when classify-bump.sh returns "none").
#
# semver-tag.yml embeds this EXACT logic inline between the
# "BEGIN bump-version"/"END bump-version" markers (D1a — see
# classify-bump.sh's header for why). THIS file is the single source of
# truth; self-test.yml's `semver-tag-inline-sync-selftest` job diffs the
# two copies so they can never silently drift.
set -eu

# BEGIN bump-version
current_tag=${1:?current tag required, e.g. v1.2.3}
bump=${2:?bump required: major|minor|patch}

version=${current_tag#v}
major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)

case "$bump" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "unknown bump: $bump (expected major|minor|patch)" >&2
    exit 1
    ;;
esac

echo "v${major}.${minor}.${patch}"
# END bump-version
