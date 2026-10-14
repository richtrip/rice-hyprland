#!/usr/bin/env bash
# DESKTOP-ONLY. Refreshes payload/ in this repo from the live configs on the machine
# you run it on. Only meaningful on the actual rice machine (user's Fedora/Hyprland
# box) — running this anywhere else (including a cloud sandbox) will overwrite payload/
# with that machine's own unrelated home directory contents, or just fail outright.
#
# After running this, `git diff` to see what changed, then commit, then run
# build-dist.sh if you want a local test tarball (releases are built by CI on a v* tag).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD="$REPO/payload"

echo "==> Syncing configs"
for dir in hypr waybar rofi swaync wlogout kitty; do
    rm -rf "$PAYLOAD/config/$dir"
    cp -r "$HOME/.config/$dir" "$PAYLOAD/config/$dir"
done

echo "==> Syncing systemd user unit"
cp "$HOME/.config/systemd/user/hyprland-session.target" "$PAYLOAD/systemd-user/"

echo "==> Syncing ~/.local/bin scripts"
rm -f "$PAYLOAD/local-bin/"*.sh
find "$HOME/.local/bin" -maxdepth 1 -name '*.sh' -exec cp {} "$PAYLOAD/local-bin/" \;

echo "==> Syncing .desktop overrides (steam + claude-desktop scaling fixes only)"
for f in steam.desktop claude-desktop-unofficial.desktop; do
    if [[ -e "$HOME/.local/share/applications/$f" ]]; then
        cp "$HOME/.local/share/applications/$f" "$PAYLOAD/applications/"
    fi
done

echo
echo "Done. Review with 'git diff', commit and push."
