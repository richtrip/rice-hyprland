# hyprland-rice

> ## ⬇️ Download the latest release
>
> **[`hyprland-rice.tar.gz`](https://github.com/richtrip/rice-hyprland/releases/latest/download/hyprland-rice.tar.gz)**
> — the installer, configs and this README in one tarball, attached to the
> [latest GitHub Release](https://github.com/richtrip/rice-hyprland/releases/latest)
> (with a `SHA256SUMS` file to verify it).
>
> ```sh
> curl -LO https://github.com/richtrip/rice-hyprland/releases/latest/download/hyprland-rice.tar.gz
> tar xzf hyprland-rice.tar.gz && cd hyprland-rice && ./install.sh
> ```
>
> Fedora (dnf) only. See [Quick start](#quick-start) for prerequisites.

A Hyprland + Waybar + Rofi desktop rice, packaged from a Fedora 44 + NVIDIA desktop
so it can be reproduced on another box. It's a
Catppuccin Mocha–themed Wayland desktop: Hyprland as the compositor, a floating Waybar
top panel, Rofi for app/window launching, SwayNotificationCenter for notifications,
wlogout for the power menu, and a handful of `Super`-key dropdown "scratchpad" terminals
(Claude CLI, Discord, Spotify, WhatsApp Web) that hide/show instead of closing.

This repo is both the config files themselves (so you can read or fork them) and an
installer that reproduces the whole setup — packages included — on a new Fedora machine.

## Quick start

**Prerequisites:** a Fedora (dnf-based) machine, a regular user with `sudo`, and an
internet connection (the installer fetches RPM Fusion, a COPR, and a font over the network).

Two equivalent ways to install, pick whichever's easier:

```sh
# Option A — clone and run
git clone https://github.com/richtrip/rice-hyprland.git
cd rice-hyprland
./install.sh

# Option B — just grab the latest release tarball, no git needed
curl -LO https://github.com/richtrip/rice-hyprland/releases/latest/download/hyprland-rice.tar.gz
tar xzf hyprland-rice.tar.gz
cd hyprland-rice
./install.sh
```

`install.sh` asks for confirmation before it does anything, installs what it can via
`sudo dnf`, and backs up (never deletes) any existing config it would overwrite. When
it finishes, log out and pick the Hyprland session at your login manager (rebooting
first if it installed the NVIDIA driver).

## Layout

```
install.sh            entry point — run this on the TARGET machine
payload/              the actual config tree, mirrors a real $HOME layout
  config/             -> ~/.config/{hypr,waybar,rofi,swaync,wlogout,kitty}
  local-bin/          -> ~/.local/bin (the scratchpad toggle scripts)
  applications/       -> ~/.local/share/applications (Steam/Claude Desktop scaling fixes)
  systemd-user/        -> ~/.config/systemd/user
scripts/
  sync-from-live.sh    DESKTOP-ONLY. Refreshes payload/ from this machine's live configs.
  build-dist.sh        Repo-only, safe anywhere. Tars install.sh+README+payload into dist/
                       (git-ignored; CI builds the published copy).
.github/workflows/release.yml   checks PRs; on a v* tag, publishes the tarball as a GitHub Release
```

Two ways to consume this repo on a new machine: `git clone` it and run `./install.sh`
directly, or just download the release tarball, extract it, and run `./install.sh`
from there — same content either way.

## What install.sh does automatically
- Enables RPM Fusion free + nonfree
- Installs the NVIDIA driver, but only if it detects an NVIDIA GPU (`lspci | grep -i nvidia`)
- Enables the `sdegler/hyprland` COPR and installs the full package list
- Copies configs into `~/.config/{hypr,waybar,rofi,swaync,wlogout,kitty}`
- Copies the `~/.local/bin` toggle scripts and the Steam/Claude-Desktop `.desktop`
  HiDPI scaling overrides
- Downloads the JetBrainsMono Nerd Font (pinned release tag, needs internet) — it's
  fetched rather than vendored so this repo and tarball stay well under GitHub's 100M
  per-file push limit (the font alone is ~230M uncompressed)
- Optionally (each behind its own prompt) installs the F9-F12 scratchpad dependencies:
  the Discord, Spotify and Google Chrome Flatpaks (user installation from Flathub, no
  sudo) and the Claude CLI via Anthropic's official installer (`https://claude.ai/install.sh`,
  downloaded then run). Run `claude` once afterwards to log in.
- Optionally (own prompt) adds the unofficial Claude Desktop dnf repo and installs
  `claude-desktop-unofficial`. It downloads the project's signing key, shows you its
  fingerprint for confirmation, imports it with `rpm --import`, and makes sure the repo
  file enforces `gpgcheck=1` with that key
- Optionally (own prompt) removes the Fedora Firefox RPM and, if the Chrome Flatpak is
  installed, makes Chrome the default browser (what Super+B opens). A second, separate
  prompt offers to permanently delete the leftover Firefox profile and cache data
  (`~/.mozilla`, `~/.config/mozilla`, `~/.cache/mozilla` — bookmarks, logins and history
  included); it is skipped if Firefox is still running. Declining the Chrome install in the
  Flatpak step leaves no default browser set, and the installer warns about it
- Backs up anything it would overwrite (`<path>.bak-<timestamp>`) instead of deleting it

Dark GTK theme and the Papirus-Dark icon theme aren't restored by install.sh at all —
`hyprland.lua`'s own autostart hook runs `gsettings set ...` for both on every Hyprland
login, so they apply themselves once the configs are in place. (An earlier version of
this repo shipped a full `dconf dump /` for this, but that pulled in unrelated personal
GNOME state — including a geolocation coordinate from night-light — for no benefit, so
it was dropped.)

## What it deliberately does NOT automate

**Monitor layout.** `hyprland.lua`'s `hl.monitor(...)` calls hardcode this machine's
DP-1/DP-2 names, 3840x2160@60 resolution, 150% scale and left/right positions. On
different hardware you must edit that block by hand before Hyprland will look right
(or even start cleanly with a single monitor).

**GNOME fallback session.** The original machine kept GNOME installed as a safety net.
Install it separately (`sudo dnf group install "GNOME Desktop"` or similar) if you want
the same fallback.

**Snapper (btrfs snapshots).** The original setup has snapper tracking two configs,
`root` (on `/`) and `home` (a separate btrfs filesystem mounted at `/home`).
This only makes sense if the new machine's filesystem layout actually matches — don't
blindly run this on a non-btrfs or differently-partitioned system. If it does match:

```sh
sudo dnf install snapper python3-dnf-plugin-snapper
sudo snapper -c root create-config /
sudo snapper -c home create-config /home
sudo sed -i "s/^ALLOW_USERS=.*/ALLOW_USERS=\"$USER\"/" /etc/snapper/configs/root /etc/snapper/configs/home
```

**OneDrive module.** The Waybar OneDrive module needs the abraunegg `onedrive` client
running as a systemd user service; `install.sh` doesn't set that up.

**Claude Desktop is opt-in.** It comes from a community repo
(`pkg.claude-desktop-debian.dev`, project: `aaddrick/claude-desktop-debian`) — an
unofficial repackaging, not built or supported by Anthropic — not RPM Fusion or the
Hyprland COPR. `install.sh` adds that repo and installs `claude-desktop-unofficial` only if
you answer yes to its own prompt. The project publishes no key fingerprint, so the installer
shows the one it downloaded (`https://pkg.claude-desktop-debian.dev/KEY.gpg`) and asks you to
confirm before importing it — trust on first use. The `.desktop` scaling override is installed either way;
it's inert without the app.

## Full package list this installs

```
hyprland hyprpaper hyprlock hypridle hyprpolkitagent
xdg-desktop-portal-hyprland hyprland-guiutils hyprpicker hyprshot
waybar rofi kitty SwayNotificationCenter wlogout
cliphist wl-clipboard grim slurp swappy playerctl
pavucontrol network-manager-applet
qt5-qtwayland qt6-qtwayland nwg-look
papirus-icon-theme jetbrains-mono-fonts fontawesome-fonts google-noto-sans-fonts
unzip
flatpak nautilus btop tmux jq xrandr xdg-utils gtk3 python3 wireplumber nm-connection-editor
```

Fedora package names drift between releases — `install.sh` reports (but doesn't abort
on) any package it fails to install, so check that list if something's missing.

## Updating this repo after further rice tweaks

On the live desktop machine:
```sh
./scripts/sync-from-live.sh   # pulls fresh configs from ~/.config etc. into payload/
git diff                      # review what actually changed
git add -A && git commit
git push
```

## Publishing a release

The tarball is built by CI, not committed. After merging to `main`, tag it:

```sh
git tag v1.1.0 && git push origin v1.1.0
```

`.github/workflows/release.yml` then builds `hyprland-rice.tar.gz` plus a `SHA256SUMS` file
and attaches them to a new GitHub Release, which the download link at the top of this page
always points to. (The link has nothing to serve until the first release exists.)
To test the archive locally, run `./scripts/build-dist.sh` — output lands in the
git-ignored `dist/`.

`sync-from-live.sh` is desktop-only — it reads this machine's real `~/.config`, so it's
meaningless (and potentially destructive to `payload/`) run anywhere else, including a
cloud sandbox. `build-dist.sh` only reads files already inside the repo, so it's safe
to run anywhere, including CI or an agentic cloud session — see CLAUDE.md.
