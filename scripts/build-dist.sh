#!/usr/bin/env bash
# Repo-only, safe to run anywhere (including a cloud sandbox with no desktop at all):
# tars up install.sh + README.md + payload/ as they currently exist in the repo into
# dist/hyprland-rice.tar.gz. Does NOT read anything outside this repo.
#
# The archive is reproducible: entries are sorted and carry fixed owner/mtime, and gzip
# omits its timestamp, so identical inputs always give a byte-identical tarball.
# dist/ is git-ignored — the published copy is built by CI and attached to a GitHub
# Release (.github/workflows/release.yml); run this locally only to test an install.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$REPO/dist/hyprland-rice.tar.gz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/hyprland-rice"

mkdir -p "$STAGE"
cp -r "$REPO/install.sh" "$REPO/README.md" "$REPO/payload" "$STAGE/"

mkdir -p "$REPO/dist"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -cf - -C "$WORK" hyprland-rice | gzip -n -9 > "$ARCHIVE"

echo "Built: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "sha256: $(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
