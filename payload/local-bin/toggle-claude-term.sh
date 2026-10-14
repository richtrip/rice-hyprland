#!/bin/bash
# Toggle a persistent Claude CLI dropdown terminal on the "claude" special workspace.
#
# Named special workspaces are scoped per-monitor in Hyprland: toggling "claude"
# acts on whichever monitor currently has focus (follow_mouse), which may not be
# DP-2, where this window actually lives -- so we pin focus to DP-2 first. Showing
# the special workspace also doesn't hand it keyboard focus on its own, so we grab
# that explicitly afterward.
CLASS="claude-scratchpad"

focus_it() {
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.focus({window = \"class:^($CLASS)\$\"})"
}

if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
    WAS_VISIBLE=$(hyprctl monitors -j | jq -e '[.[] | select(.specialWorkspace.name == "special:claude")] | length > 0')
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"claude\")"
    # Only showing (not hiding) needs an explicit window focus grab.
    [ "$WAS_VISIBLE" = "false" ] && focus_it
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"kitty --class $CLASS --title claude -e tmux new-session -A -s claude /home/richard/.local/bin/claude\")"
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"claude\")"
    sleep 0.3
    focus_it
fi
