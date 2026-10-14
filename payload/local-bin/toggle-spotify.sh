#!/bin/bash
# Toggle a persistent Spotify dropdown window on the "spotify" special workspace.
#
# See toggle-claude-term.sh for why this pins focus to DP-2 before toggling
# (named special workspaces are scoped per-monitor) and grabs window focus
# explicitly afterward (showing a workspace doesn't hand it keyboard focus).
CLASS="spotify"

focus_it() {
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.focus({window = \"class:^($CLASS)\$\"})"
}

if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
    WAS_VISIBLE=$(hyprctl monitors -j | jq -e '[.[] | select(.specialWorkspace.name == "special:spotify")] | length > 0')
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"spotify\")"
    [ "$WAS_VISIBLE" = "false" ] && focus_it
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"flatpak run com.spotify.Client\")"
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"spotify\")"
    sleep 1
    focus_it
fi
