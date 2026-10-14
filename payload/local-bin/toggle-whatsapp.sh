#!/bin/bash
# Toggle a persistent WhatsApp Web dropdown window on the "whatsapp" special workspace.
# Chrome's --app= mode derives WM_CLASS from the URL as "chrome-<host>__-<Profile>" —
# confirmed by launching it once and reading hyprctl clients -j.
#
# See toggle-claude-term.sh for why this pins focus to DP-2 before toggling
# (named special workspaces are scoped per-monitor) and grabs window focus
# explicitly afterward (showing a workspace doesn't hand it keyboard focus).
CLASS="chrome-web.whatsapp.com__-Default"

focus_it() {
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.focus({window = \"class:^($CLASS)\$\"})"
}

if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null; then
    WAS_VISIBLE=$(hyprctl monitors -j | jq -e '[.[] | select(.specialWorkspace.name == "special:whatsapp")] | length > 0')
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"whatsapp\")"
    [ "$WAS_VISIBLE" = "false" ] && focus_it
else
    hyprctl dispatch "hl.dsp.exec_cmd(\"flatpak run com.google.Chrome --app=https://web.whatsapp.com\")"
    hyprctl dispatch 'hl.dsp.focus({monitor = "DP-2"})'
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"whatsapp\")"
    sleep 1
    focus_it
fi
