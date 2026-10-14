#!/bin/bash
# Toggle a persistent Discord dropdown window on the "discord" special workspace.
#
# See toggle-claude-term.sh for why this pins focus to DP-2 before toggling
# (named special workspaces are scoped per-monitor) and grabs window focus
# explicitly afterward (showing a workspace doesn't hand it keyboard focus).
CLASS="discord"

focus_it() {
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.focus({window = \"class:^($CLASS)\$\"})"
}

if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
    WAS_VISIBLE=$(hyprctl monitors -j | jq -e '[.[] | select(.specialWorkspace.name == "special:discord")] | length > 0')
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"discord\")"
    [ "$WAS_VISIBLE" = "false" ] && focus_it
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"flatpak run com.discordapp.Discord\")"
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"discord\")"
    sleep 1
    focus_it
fi
