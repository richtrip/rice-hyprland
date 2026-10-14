# hyprland-rice

Richard's Hyprland + Waybar + Rofi desktop rice, packaged from his Fedora 44 + NVIDIA
(RTX 2080 Super) machine ("KILLER") so it can be reproduced on another box. It's a
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

# Option B — just grab the prebuilt tarball, no git needed
curl -LO https://github.com/richtrip/rice-hyprland/raw/main/dist/hyprland-rice.tar.gz
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
  build-dist.sh        Repo-only, safe anywhere. Tars install.sh+README+payload into dist/.
dist/hyprland-rice.tar.gz   prebuilt, downloadable copy of the above three things
```

Two ways to consume this repo on a new machine: `git clone` it and run `./install.sh`
directly, or just download `dist/hyprland-rice.tar.gz`, extract it, and run `./install.sh`
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
`root` (on `/`) and `home` (a separate 3-disk btrfs RAID0 array mounted at `/home`).
This only makes sense if the new machine's filesystem layout actually matches — don't
blindly run this on a non-btrfs or differently-partitioned system. If it does match:

```sh
sudo dnf install snapper python3-dnf-plugin-snapper
sudo snapper -c root create-config /
sudo snapper -c home create-config /home
sudo sed -i 's/^ALLOW_USERS=.*/ALLOW_USERS="richard"/' /etc/snapper/configs/root /etc/snapper/configs/home
```

**Claude Desktop.** Comes from a third-party repo (`pkg.claude-desktop-debian.dev`),
not RPM Fusion or the Hyprland COPR, so it's intentionally left out of the automated
package list. The `.desktop` scaling override is installed either way, it's just inert
until you add that repo and install the app yourself.

## Full package list this installs

```
hyprland hyprpaper hyprlock hypridle hyprpolkitagent
xdg-desktop-portal-hyprland hyprland-guiutils hyprpicker hyprshot
waybar rofi kitty SwayNotificationCenter wlogout
cliphist wl-clipboard grim slurp swappy playerctl
pavucontrol network-manager-applet
qt5-qtwayland qt6-qtwayland nwg-look
papirus-icon-theme jetbrains-mono-fonts fontawesome-fonts google-noto-sans-fonts
```

Fedora package names drift between releases — `install.sh` reports (but doesn't abort
on) any package it fails to install, so check that list if something's missing.

## Updating this repo after further rice tweaks

On the live desktop machine:
```sh
./scripts/sync-from-live.sh   # pulls fresh configs from ~/.config etc. into payload/
git diff                      # review what actually changed
git add -A && git commit
./scripts/build-dist.sh       # refreshes dist/hyprland-rice.tar.gz to match
git add dist/hyprland-rice.tar.gz && git commit
```

`sync-from-live.sh` is desktop-only — it reads this machine's real `~/.config`, so it's
meaningless (and potentially destructive to `payload/`) run anywhere else, including a
cloud sandbox. `build-dist.sh` only reads files already inside the repo, so it's safe
to run anywhere, including CI or an agentic cloud session — see CLAUDE.md.
