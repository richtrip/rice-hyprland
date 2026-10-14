#!/usr/bin/env python3
"""Show all Hyprland keybinds in a searchable Rofi list, read-only."""
import json
import subprocess

MOD_BITS = [
    (64, "SUPER"),
    (4, "CTRL"),
    (8, "ALT"),
    (1, "SHIFT"),
]

KEY_LABELS = {
    "mouse:272": "Mouse L",
    "mouse:273": "Mouse R",
    "mouse_down": "Scroll ↓",
    "mouse_up": "Scroll ↑",
}


def mod_string(modmask):
    parts = [name for bit, name in MOD_BITS if modmask & bit]
    return " + ".join(parts)


def key_string(bind):
    key = bind["key"]
    return KEY_LABELS.get(key, key)


def format_bind(bind):
    mods = mod_string(bind["modmask"])
    key = key_string(bind)
    combo = " + ".join([p for p in (mods, key) if p])
    return combo, bind["description"]


def main():
    out = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True)
    binds = json.loads(out.stdout)
    binds = [b for b in binds if b.get("description")]

    rows = [format_bind(b) for b in binds]
    width = max(len(combo) for combo, _ in rows) if rows else 0
    lines = [f"{combo.ljust(width)}   {desc}" for combo, desc in rows]

    rofi = subprocess.Popen(
        ["rofi", "-dmenu", "-i", "-p", " Keybinds", "-no-custom"],
        stdin=subprocess.PIPE,
    )
    rofi.communicate("\n".join(lines).encode())


if __name__ == "__main__":
    main()
