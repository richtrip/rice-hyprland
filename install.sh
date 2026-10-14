#!/usr/bin/env bash
# Installs the Hyprland/Waybar/Rofi rice (packaged from user's Fedora 44 box)
# onto a new machine. Run this from inside the extracted archive directory:
#   tar xzf hyprland-rice-*.tar.gz && cd hyprland-rice-* && ./install.sh
#
# This script:
#  - installs Fedora packages (RPM Fusion, a Hyprland COPR, then the rice's dnf list)
#  - conditionally installs the NVIDIA driver (only if an NVIDIA GPU is detected)
#  - copies configs into ~/.config, scripts into ~/.local/bin, and the two .desktop
#    overrides into ~/.local/share/applications
#  - downloads the JetBrainsMono Nerd Font into ~/.local/share/fonts (needs internet;
#    not vendored in the archive so the repo/tarball stays well under GitHub's 100M
#    per-file limit)
#
# It backs up anything it would overwrite rather than deleting it.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$HERE/payload"
TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$1"; exit 1; }

confirm() {
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

[[ -d "$PAYLOAD" ]] || die "payload/ not found next to this script — run it from inside the extracted archive."
command -v dnf >/dev/null 2>&1 || die "This installer is Fedora/dnf-specific. Aborting on a non-dnf system."

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || true)"
[[ -n "$FEDORA_VER" ]] || die "Could not detect Fedora release version (rpm -E %fedora failed)."

log "Target: Fedora $FEDORA_VER, user $USER"
echo "This will install system packages (needs sudo), enable a COPR and RPM Fusion,"
echo "and write into ~/.config, ~/.local/bin, ~/.local/share/fonts and ~/.local/share/applications."
confirm "Continue?" || { echo "Aborted."; exit 0; }

backup_if_exists() {
    local path="$1"
    if [[ -e "$path" ]]; then
        warn "Backing up existing $path -> ${path}.bak-$TS"
        mv "$path" "${path}.bak-$TS"
    fi
}

### 1. RPM Fusion ############################################################
log "Enabling RPM Fusion (free + nonfree)"
if ! dnf repolist 2>/dev/null | grep -qi rpmfusion-free; then
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
else
    echo "RPM Fusion already enabled, skipping."
fi

### 2. NVIDIA driver (only if an NVIDIA GPU is present) ######################
if lspci | grep -qi nvidia; then
    log "NVIDIA GPU detected"
    if confirm "Install the NVIDIA driver (akmod-nvidia, xorg-x11-drv-nvidia-cuda)?"; then
        sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
        warn "Secure Boot must be disabled (or the akmod kernel module signed) for the driver to load."
        warn "A reboot is required after this script finishes, before Hyprland will run on NVIDIA."
    fi
else
    echo "No NVIDIA GPU detected — skipping the driver step."
fi

### 3. Hyprland COPR ##########################################################
log "Enabling Hyprland COPR (sdegler/hyprland)"
sudo dnf copr enable -y sdegler/hyprland

### 4. Package list ###########################################################
log "Installing packages"
PACKAGES=(
    hyprland hyprpaper hyprlock hypridle hyprpolkitagent
    xdg-desktop-portal-hyprland hyprland-guiutils hyprpicker hyprshot
    waybar rofi kitty SwayNotificationCenter wlogout
    cliphist wl-clipboard grim slurp swappy playerctl
    pavucontrol network-manager-applet
    qt5-qtwayland qt6-qtwayland nwg-look
    papirus-icon-theme jetbrains-mono-fonts fontawesome-fonts google-noto-sans-fonts
    unzip
)
FAILED=()
for pkg in "${PACKAGES[@]}"; do
    if ! sudo dnf install -y "$pkg"; then
        FAILED+=("$pkg")
    fi
done
if ((${#FAILED[@]})); then
    warn "These packages failed to install — package names can drift between Fedora releases, check 'dnf search <name>':"
    printf '    %s\n' "${FAILED[@]}"
fi

### 5. Configs #################################################################
log "Installing configs into ~/.config"
for dir in hypr waybar rofi swaync wlogout kitty; do
    backup_if_exists "$HOME/.config/$dir"
    cp -r "$PAYLOAD/config/$dir" "$HOME/.config/$dir"
done

mkdir -p "$HOME/.config/systemd/user"
backup_if_exists "$HOME/.config/systemd/user/hyprland-session.target"
cp "$PAYLOAD/systemd-user/hyprland-session.target" "$HOME/.config/systemd/user/hyprland-session.target"
systemctl --user daemon-reload || true

### 6. Scripts ##################################################################
log "Installing ~/.local/bin scripts"
mkdir -p "$HOME/.local/bin"
cp "$PAYLOAD/local-bin/"*.sh "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"*.sh

### 7. Font ######################################################################
NERD_FONT_VERSION="v3.3.0"
log "Downloading JetBrainsMono Nerd Font ($NERD_FONT_VERSION)"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
backup_if_exists "$FONT_DIR"
mkdir -p "$FONT_DIR"
FONT_ZIP="$(mktemp --suffix=.zip)"
curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip" -o "$FONT_ZIP"
unzip -q -o "$FONT_ZIP" -d "$FONT_DIR" -x "*Windows Compatible*" "LICENSE*" "README*"
rm -f "$FONT_ZIP"
fc-cache -f "$HOME/.local/share/fonts" >/dev/null

### 8. .desktop overrides ########################################################
log "Installing .desktop overrides (Steam + Claude Desktop HiDPI scaling fixes)"
mkdir -p "$HOME/.local/share/applications"
for f in "$PAYLOAD/applications/"*.desktop; do
    name="$(basename "$f")"
    if [[ -e "$HOME/.local/share/applications/$name" ]]; then
        warn "$name already exists, backing up"
        cp "$HOME/.local/share/applications/$name" "$HOME/.local/share/applications/${name}.bak-$TS"
    fi
    cp "$f" "$HOME/.local/share/applications/$name"
done
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

### Done ##########################################################################
log "Done."
cat <<'EOF'

Manual steps still needed:
  1. If the NVIDIA driver was installed: reboot before trying to start Hyprland.
  2. Log out and choose the Hyprland session at your login manager.
  3. GNOME is NOT installed by this script as a fallback session — install it separately
     if you want that safety net, same as the original machine.
  4. Snapper (btrfs snapshots) was NOT automated here — it's specific to btrfs subvolumes
     named like the source machine's. See README.md's "Snapper" section if you want it.
  5. Claude Desktop (claude-desktop-unofficial) was not installed by this script either —
     it comes from a third-party repo (pkg.claude-desktop-debian.dev), not RPM Fusion/COPR.
     The .desktop override for it is now in place but inert until you install that app.

Re-check hyprland.lua's monitor block (hl.monitor outputs/positions/scale) — it hardcodes
this machine's DP-1/DP-2 layout and 150% scale, which will be wrong on different hardware.
EOF
