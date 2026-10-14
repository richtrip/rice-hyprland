#!/usr/bin/env bash
# Installs the Hyprland/Waybar/Rofi rice (packaged from richard's Fedora 44 box)
# onto a new machine. Run this from inside the extracted archive directory:
#   tar xzf hyprland-rice.tar.gz && cd hyprland-rice && ./install.sh
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

STEP_FAILURES=()   # non-fatal steps that failed, reported at the end
BACKUPS=()         # every path moved aside, listed if the script dies midway
TMP_FILES=()       # temp files removed on exit

on_exit() {
    local rc=$?
    ((${#TMP_FILES[@]})) && rm -f "${TMP_FILES[@]}"
    if ((rc != 0)); then
        printf '\033[1;31mInstall aborted (exit %d).\033[0m\n' "$rc" >&2
        if ((${#BACKUPS[@]})); then
            echo "Anything this run moved aside is still intact at:" >&2
            printf '    %s\n' "${BACKUPS[@]}" >&2
        fi
    fi
}
trap on_exit EXIT

# try "<description>" cmd...  — run a non-essential step; record failure instead of aborting.
try() {
    local desc="$1"; shift
    if ! "$@"; then
        warn "$desc failed — continuing."
        STEP_FAILURES+=("$desc")
        return 1
    fi
}

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
        BACKUPS+=("${path}.bak-$TS")
    fi
}

### 1. RPM Fusion ############################################################
log "Enabling RPM Fusion (free + nonfree)"
if ! dnf repolist 2>/dev/null | grep -qi rpmfusion-free; then
    try "RPM Fusion repo setup" sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" || true
else
    echo "RPM Fusion already enabled, skipping."
fi

### 2. NVIDIA driver (only if an NVIDIA GPU is present) ######################
HAVE_NVIDIA=0
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -qi nvidia && HAVE_NVIDIA=1
else
    warn "lspci not found (install 'pciutils') — cannot auto-detect an NVIDIA GPU."
    if confirm "Do you have an NVIDIA GPU and want the driver installed anyway?"; then
        HAVE_NVIDIA=1
    fi
fi
if ((HAVE_NVIDIA)); then
    log "NVIDIA GPU detected"
    if confirm "Install the NVIDIA driver (akmod-nvidia, xorg-x11-drv-nvidia-cuda)?"; then
        if try "NVIDIA driver install" sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda; then
            warn "Secure Boot must be disabled (or the akmod kernel module signed) for the driver to load."
            warn "A reboot is required after this script finishes, before Hyprland will run on NVIDIA."
        fi
    fi
else
    echo "No NVIDIA GPU detected — skipping the driver step."
fi

### 3. Hyprland COPR ##########################################################
log "Enabling Hyprland COPR (sdegler/hyprland)"
try "Hyprland COPR enable (sdegler/hyprland)" sudo dnf copr enable -y sdegler/hyprland || true

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
    # Used by keybinds / waybar / the toggle scripts:
    flatpak nautilus btop tmux jq xrandr xdg-utils gtk3 python3 wireplumber nm-connection-editor
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
# SHA-256 of JetBrainsMono.zip for the tag above (matches upstream's SHA-256.txt for the release).
# Update this together with NERD_FONT_VERSION.
NERD_FONT_SHA256="2d83782a350b604bfa70fce880604a41a7f77c3eec8f922f9cdc3c20952ddbe4"
log "Downloading JetBrainsMono Nerd Font ($NERD_FONT_VERSION)"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
install_font() {
    # Back up outside ~/.local/share/fonts so fontconfig doesn't index both copies.
    if [[ -e "$FONT_DIR" ]]; then
        local bak_root="$HOME/.local/share/font-backups"
        mkdir -p "$bak_root"
        warn "Backing up existing $FONT_DIR -> $bak_root/JetBrainsMonoNerd.bak-$TS"
        mv "$FONT_DIR" "$bak_root/JetBrainsMonoNerd.bak-$TS"
        BACKUPS+=("$bak_root/JetBrainsMonoNerd.bak-$TS")
    fi
    local zip
    zip="$(mktemp --suffix=.zip)"
    TMP_FILES+=("$zip")
    curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip" -o "$zip" || return 1
    echo "${NERD_FONT_SHA256}  $zip" | sha256sum -c --quiet - \
        || { echo "Checksum mismatch for JetBrainsMono.zip" >&2; return 1; }
    mkdir -p "$FONT_DIR" || return 1
    unzip -q -o "$zip" -d "$FONT_DIR" -x "*Windows Compatible*" "LICENSE*" "README*" || return 1
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null || return 1
}
try "JetBrainsMono Nerd Font install" install_font || true

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

### 9. F9-F12 scratchpad apps ###################################################
# F9/F10/F11 launch Flatpaks (see ~/.local/bin/toggle-*.sh); F12 runs ~/.local/bin/claude.
# Flatpaks go in the per-user installation, so no sudo is needed. These are third-party
# downloads (Flathub, claude.ai), so each is confirmed separately.
FLATPAK_APPS=(com.discordapp.Discord com.spotify.Client com.google.Chrome)

install_flatpaks() {
    command -v flatpak >/dev/null 2>&1 || { echo "flatpak is not installed." >&2; return 1; }
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
    flatpak install --user -y flathub "${FLATPAK_APPS[@]}"
}

install_claude_cli() {
    if [[ -x "$HOME/.local/bin/claude" ]]; then
        echo "Claude CLI already present at ~/.local/bin/claude, skipping."
        return 0
    fi
    local script
    script="$(mktemp --suffix=.sh)"
    TMP_FILES+=("$script")
    # Download first, then run, rather than piping curl straight into bash.
    curl -fsSL https://claude.ai/install.sh -o "$script" || return 1
    bash "$script" || return 1
    [[ -x "$HOME/.local/bin/claude" ]] \
        || { echo "Installer finished but ~/.local/bin/claude was not created." >&2; return 1; }
}

log "Scratchpad apps (F9-F12)"
if confirm "Install Discord, Spotify and Google Chrome (WhatsApp Web) as user Flatpaks from Flathub?"; then
    try "Flatpak apps (Discord, Spotify, Chrome)" install_flatpaks || true
fi
if confirm "Install the Claude CLI via Anthropic's official installer (https://claude.ai/install.sh)?"; then
    try "Claude CLI install" install_claude_cli || true
fi

### 10. Claude Desktop (unofficial community build) ##############################
# Third-party repo (https://github.com/aaddrick/claude-desktop-debian) — NOT built or
# supported by Anthropic. Ships the `claude-desktop-unofficial` package that the
# payload/applications/claude-desktop-unofficial.desktop override targets.
CLAUDE_DESKTOP_REPO_URL="https://pkg.claude-desktop-debian.dev/rpm/claude-desktop-unofficial.repo"
CLAUDE_DESKTOP_KEY_URL="https://pkg.claude-desktop-debian.dev/KEY.gpg"   # same key the project's APT docs use
CLAUDE_DESKTOP_REPO_FILE="/etc/yum.repos.d/claude-desktop-unofficial.repo"

# Make sure a downloaded .repo file verifies package signatures against the project's key:
# adds gpgkey= if missing, and gpgcheck=1 if missing or set to 0. Operates on a local file.
harden_repo_file() {
    local f="$1"
    if ! grep -q '^gpgkey=' "$f"; then
        sed -i "0,/^\[.*\]/s|^\[.*\]|&\ngpgkey=${CLAUDE_DESKTOP_KEY_URL}|" "$f"
    fi
    if grep -q '^gpgcheck=0' "$f"; then
        warn "Repo file set gpgcheck=0; changing to gpgcheck=1 so packages must be signed."
        sed -i 's/^gpgcheck=0/gpgcheck=1/' "$f"
    elif ! grep -q '^gpgcheck=' "$f"; then
        sed -i "0,/^\[.*\]/s|^\[.*\]|&\ngpgcheck=1|" "$f"
    fi
}

install_claude_desktop() {
    local repo key
    repo="$(mktemp --suffix=.repo)"
    key="$(mktemp --suffix=.gpg)"
    TMP_FILES+=("$repo" "$key")

    # Signing key: no fingerprint is published by the project, so show it and ask (trust-on-first-use).
    curl -fsSL "$CLAUDE_DESKTOP_KEY_URL" -o "$key" || return 1
    if command -v gpg >/dev/null 2>&1; then
        echo "Signing key downloaded from $CLAUDE_DESKTOP_KEY_URL:"
        gpg --show-keys --with-fingerprint "$key" || return 1
    else
        warn "gpg not found — cannot display the key fingerprint."
    fi
    confirm "Import this key into the RPM keyring and trust it for this repo?" || return 1
    sudo rpm --import "$key" || return 1

    curl -fsSL "$CLAUDE_DESKTOP_REPO_URL" -o "$repo" || return 1
    harden_repo_file "$repo"
    if [[ -e "$CLAUDE_DESKTOP_REPO_FILE" ]]; then
        warn "Backing up existing $CLAUDE_DESKTOP_REPO_FILE -> ${CLAUDE_DESKTOP_REPO_FILE}.bak-$TS"
        sudo mv "$CLAUDE_DESKTOP_REPO_FILE" "${CLAUDE_DESKTOP_REPO_FILE}.bak-$TS" || return 1
        BACKUPS+=("${CLAUDE_DESKTOP_REPO_FILE}.bak-$TS")
    fi
    sudo install -m 644 "$repo" "$CLAUDE_DESKTOP_REPO_FILE" || return 1
    sudo dnf install -y claude-desktop-unofficial
}

log "Claude Desktop (unofficial community build)"
echo "This adds a third-party dnf repo (pkg.claude-desktop-debian.dev). It is a community"
echo "repackaging, not an Anthropic product. Review the repo file if you want to be careful."
if confirm "Add that repo and install claude-desktop-unofficial?"; then
    try "Claude Desktop (unofficial) install" install_claude_desktop || true
fi

### Done ##########################################################################
log "Done."
if ((${#STEP_FAILURES[@]})); then
    warn "These non-fatal steps failed and need attention:"
    printf '    %s\n' "${STEP_FAILURES[@]}"
fi
cat <<'EOF'

Manual steps still needed:
  1. If the NVIDIA driver was installed: reboot before trying to start Hyprland.
  2. Log out and choose the Hyprland session at your login manager.
  3. GNOME is NOT installed by this script as a fallback session — install it separately
     if you want that safety net, same as the original machine.
  4. Snapper (btrfs snapshots) was NOT automated here — it's specific to btrfs subvolumes
     named like the source machine's. See README.md's "Snapper" section if you want it.
  5. Claude Desktop (claude-desktop-unofficial) comes from a third-party repo
     (pkg.claude-desktop-debian.dev) and is installed in step 10 only if you said yes.
     The .desktop override is in place either way, but inert without the app.
  6. The Waybar OneDrive module needs the abraunegg `onedrive` client set up as a systemd
     user service — not automated. (The F9-F12 apps are handled in step 9 if you said yes;
     if you declined, F9-F11 need the Discord/Spotify/Chrome Flatpaks and F12 needs
     ~/.local/bin/claude. Run `claude` once to log in.)

Re-check hyprland.lua's monitor block (hl.monitor outputs/positions/scale) — it hardcodes
this machine's DP-1/DP-2 layout and 150% scale, which will be wrong on different hardware.
EOF
