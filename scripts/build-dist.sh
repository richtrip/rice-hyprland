#!/usr/bin/env bash
# Repo-only, safe to run anywhere (including a cloud sandbox with no desktop at all):
# tars up install.sh + README.md + payload/ as they currently exist in the repo into
# dist/hyprland-rice.tar.gz. Does NOT read anything outside this repo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$REPO/dist/hyprland-rice.tar.gz"
WORK="$(mktemp -d)"
STAGE="$WORK/hyprland-rice"

mkdir -p "$STAGE"
cp -r "$REPO/install.sh" "$REPO/README.md" "$REPO/payload" "$STAGE/"

mkdir -p "$REPO/dist"
tar czf "$ARCHIVE" -C "$WORK" hyprland-rice
rm -rf "$WORK"

echo "Built: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "git add dist/hyprland-rice.tar.gz && git commit to update the tracked copy."
