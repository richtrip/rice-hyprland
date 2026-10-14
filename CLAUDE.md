# hyprland-rice

Packaged Hyprland + Waybar + Rofi desktop rice from a Fedora 44 + NVIDIA
desktop, plus an installer that reproduces it on another Fedora box.
This repo is the installer/config package itself — it is not a running application,
and the only CI is a GitHub Actions workflow that syntax-checks the shell scripts and builds/publishes
the release tarball (see `.github/workflows/release.yml` below); nothing here is functionally tested.

## Layout

- `install.sh` — entry point, run by a human on the TARGET machine. Installs Fedora
  packages (RPM Fusion, the `sdegler/hyprland` COPR, NVIDIA driver if a GPU is
  detected, the Nerd Font), then copies `payload/` into place.
- `payload/` — the actual config tree, mirroring a real `$HOME` layout 1:1
  (`payload/config/hypr` → `~/.config/hypr`, etc). This is the real content; edit
  configs here.
- `scripts/sync-from-live.sh` — **desktop-only.** Pulls `payload/` fresh from a live
  machine's `~/.config`. Never run this in a cloud/CI sandbox — there is no real
  desktop there, so it will either fail on missing paths or silently overwrite
  `payload/` with the sandbox's own unrelated files. Nothing in a cloud session
  should ever invoke this script.
- `scripts/build-dist.sh` — **safe anywhere.** Reads only files already in the repo
  (`install.sh`, `README.md`, `payload/`) and tars them into `dist/hyprland-rice.tar.gz`
  (reproducible output; `dist/` is git-ignored).
  Use it to sanity-check that the archive builds; do not commit its output.
- `.github/workflows/release.yml` — CI. On PRs/pushes to `main` it runs `bash -n` over
  the shell scripts and builds the tarball. Pushing a `v*` tag builds
  `hyprland-rice.tar.gz` + `SHA256SUMS` and publishes them as a GitHub Release; the
  README's download link targets `/releases/latest/download/hyprland-rice.tar.gz`.
  The tarball is **not** tracked in git (`dist/` is git-ignored) — there is nothing to
  rebuild or commit after editing `payload/`, `install.sh` or `README.md`. Keep the
  asset name `hyprland-rice.tar.gz` stable or the README link breaks. Cutting a release
  is the user's call: don't push tags unless asked.

## Critical gotchas when editing payload/config/hypr/hyprland.lua

This is **not** stock Hyprland's classic `hyprland.conf` keyword syntax, and not
stock Hyprland's dispatcher API either — it's a specific fork with a Lua config:

- Hyprland 0.56 on this fork uses a Lua config (`hyprland.lua`), configured via
  `hl.config({...})`, `hl.monitor({...})`, `hl.workspace_rule({...})`, `hl.on(event,
  fn)`, `hl.env(k, v)`, `hl.animation({...})`, and window rules — not the classic
  `general { ... }` block / `bind = ` line syntax from upstream Hyprland docs.
- `hyprctl dispatch` on this fork takes a **literal Lua expression**, not a classic
  `dispatcher args` string: `hyprctl dispatch 'hl.dsp.window.close()'` works,
  `hyprctl dispatch closewindow address:...` does not (Lua parse error).
- There is no `kill_active`/`close_window` dispatcher; use `hl.dsp.window.close()` /
  `hl.dsp.window.kill()` (nested under `window`).
- `hl.dsp.window.resize({relative = false})` (absolute sizing) silently no-ops —
  always compute a delta and use `relative = true`.
- `hl.dsp.window.*` / `hl.dsp.focus(...)` act on whatever window is currently
  "active," with no window-selector argument, and `follow_mouse` can change that
  between calls — multi-step scripted changes to one window must re-issue
  `hl.dsp.focus({window = "address:0x..."})` before *every* mutating call.
- A `window_rule` only applies at window *creation* — reloading the config does not
  retroactively move an already-open window into a special workspace.
- There is no Hyprland binary, display, or compositor in a cloud sandbox, so
  `Hyprland --verify-config -c payload/config/hypr/hyprland.lua` (the normal way to
  validate this file) cannot run there. Read changes carefully and diff against the
  working version instead of relying on that check; flag in the PR description that
  it couldn't be verified and should be checked on the real machine.

## Hardware-specific values baked into these configs

`hyprland.lua`'s `hl.monitor(...)` calls hardcode the source machine's output names
(`DP-1`, `DP-2`), resolution (3840x2160@60), 150% scale, and left/right layout, and
other files assume an NVIDIA GPU. These are facts about one specific machine
(the source desktop), not generic defaults — don't "fix" or genericize them unless asked to
adapt the rice for different hardware, and if asked, say explicitly what you changed
and why so it's easy to revert.

## install.sh conventions

- Fedora/dnf-specific by design; it checks for `dnf` and aborts cleanly on other
  distros rather than guessing an equivalent.
- Package names drift between Fedora releases — the package loop tolerates
  individual failures and reports them at the end rather than aborting the whole
  install over one renamed package.
- Backs up anything it would overwrite (`<path>.bak-<timestamp>`) instead of
  deleting it — preserve that pattern if you add new install steps.
- The Nerd Font is downloaded from a pinned `ryanoasis/nerd-fonts` release tag
  (`NERD_FONT_VERSION` near the top of the font step), not vendored, specifically to
  keep this repo and the release tarball under GitHub's 100M per-file push
  limit. If asked to bump the font version, update that variable and confirm the
  release tag and asset filename (`JetBrainsMono.zip`) still match upstream.
- Never add install steps that assume `sudo` is passwordless — this installer always
  prompts.

## Don't reintroduce a full dconf dump

An earlier version of this repo shipped `payload/dconf-settings.ini` from `dconf dump /`
to restore dark-theme/icon-theme settings. It was removed: `dconf dump /` pulls in the
*entire* dconf database, which included a geolocation coordinate (night-light's last
known location) and other unrelated personal GNOME state — not something to commit to
a repo. It was also redundant, since `hyprland.lua`'s autostart hook already sets both
via `gsettings set` on every login. If a future dconf-restore need comes up, dump only
the specific keys required (`dconf dump /org/gnome/desktop/interface/`), never `/`.

## Things intentionally not automated (see README.md for detail)

GNOME fallback session and snapper/btrfs snapshot setup (filesystem-layout-specific),
plus the Waybar OneDrive client (`onedrive` service, interactive Microsoft login). Don't
silently add automation for these without flagging the tradeoff — they were left manual
on purpose.

Third-party installs that ARE automated, but only behind their own confirmation prompt
in `install.sh`: the F9–F11 Flatpaks, the Claude CLI, and Claude Desktop (community
repo `pkg.claude-desktop-debian.dev`, signing key shown for confirmation and imported,
`gpgcheck=1` enforced). Keep any new third-party step opt-in, non-fatal and documented
in the README the same way.

Destructive steps follow the same rule. The Firefox removal (step 11: `dnf remove firefox`,
then Chrome set as the default browser) is opt-in, and deleting the leftover Firefox
profile/cache directories is a second, separate prompt — this is a deliberate exception to
the "back up instead of delete" convention, requested by the owner because the profiles are
unused. It must run after the Chrome Flatpak step so there is a browser to make the default,
and it never touches anything outside the three listed Mozilla directories.
