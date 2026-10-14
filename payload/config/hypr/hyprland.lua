-- Hyprland config — Catppuccin Mocha
-- Docs: https://wiki.hypr.land/Configuring/Start/

-----------------
---- COLOURS ----
-----------------

-- Catppuccin Mocha
local c = {
    base     = "1e1e2e",
    mantle   = "181825",
    crust    = "11111b",
    surface0 = "313244",
    surface1 = "45475a",
    overlay0 = "6c7086",
    text     = "cdd6f4",
    lavender = "b4befe",
    mauve    = "cba6f7",
    blue     = "89b4fa",
    sapphire = "74c7ec",
    red      = "f38ba8",
}

local function rgba(hex, alpha) return "rgba(" .. hex .. alpha .. ")" end


------------------
---- MONITORS ----
------------------

-- DP-2 on the left, DP-1 on the right, both at 150% (each behaves like a 2560x1440 desktop).
-- 3840 / 1.5 = 2560, so DP-1 starts at x = 2560. Change both lines together if you change the scale.
hl.monitor({ output = "DP-2", mode = "3840x2160@60", position = "0x0",    scale = 1.5 })
hl.monitor({ output = "DP-1", mode = "3840x2160@60", position = "2560x0", scale = 1.5 })
-- Anything else that gets plugged in
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Treat the left screen (DP-2) as primary. Hyprland detects DP-1 first, so without
-- this the cursor, first focus and XWayland's primary output all land on the right.
hl.config({
    cursor = {
        default_monitor = "DP-2",
    },
})

-- Keep odd workspaces on the left screen and even ones on the right
for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = (i % 2 == 1) and "DP-2" or "DP-1", persistent = i <= 2 })
end


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"
local browser     = "gtk-launch \"$(xdg-settings get default-web-browser)\"" -- whatever the default browser is
local launcher    = "rofi -show drun"
local windows     = "rofi -show window"
local clipboard   = "cliphist list | rofi -dmenu -p ' Clipboard' -display-columns 2 | cliphist decode | wl-copy"
local powerMenu   = "pidof wlogout || wlogout -b 5 -T 600 -B 600"
local lock        = "loginctl lock-session"


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Prefer Wayland for toolkits that can use it
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Steam's client UI runs under XWayland and doesn't pick up the 1.5x monitor
-- scale on its own, so its text renders at a 1080p-era size on our 4K screens.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.5")


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))
    hl.exec_cmd("xrandr --output DP-2 --primary") -- primary display for X11 apps and games

    -- Hand our environment to systemd, then mark the graphical session as started
    -- (~/.config/systemd/user/hyprland-session.target) so portals etc. can run.
    -- --all so apps launched via portals/D-Bus (e.g. links opened from Flatpak apps)
    -- get the same toolkit/scaling variables as apps launched from Hyprland itself.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all"
        .. " && systemctl --user start hyprland-session.target"
        .. " && systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Dark mode and Papirus icons for GTK apps
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
end)

-- End the graphical session cleanly so it doesn't linger after logging out
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 7,

        border_size = 2,

        col = {
            active_border   = rgba(c.overlay0, "cc"),
            inactive_border = rgba(c.surface0, "88"),
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 7,
        rounding_power = 2.5,

        active_opacity   = 1.0,
        inactive_opacity = 0.94,

        dim_inactive = true,
        dim_strength = 0.06,

        shadow = {
            enabled        = true,
            range          = 22,
            render_power   = 3,
            offset         = { 0, 6 },
            color          = rgba(c.crust, "aa"),
            color_inactive = rgba(c.crust, "66"),
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            noise             = 0.02,
            contrast          = 1.0,
            brightness        = 0.9,
            vibrancy          = 0.2,
            vibrancy_darkness = 0.3,
            popups            = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",         { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3.5,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slidevert" })

hl.config({
    dwindle = {
        preserve_split = true,
        force_split    = 2, -- new windows always open to the right/below, regardless of mouse position
    },
    master = {
        new_status = "master",
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color        = rgba(c.crust, "ff"),
        focus_on_activate       = true,
    },
    xwayland = {
        force_zero_scaling = true,
    },
    ecosystem = {
        no_update_news   = true,
        no_donation_nag  = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "gb",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity   = -0.3,   -- -1.0 (slowest) to 1.0 (fastest)
        accel_profile = "flat", -- no mouse acceleration
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Apps and menus
hl.bind(mainMod .. " + Return",       hl.dsp.exec_cmd(terminal),    { desc = "Terminal" })
hl.bind("F12", hl.dsp.exec_cmd("~/.local/bin/toggle-claude-term.sh"), { desc = "Claude CLI (toggle)" })
hl.bind("F11", hl.dsp.exec_cmd("~/.local/bin/toggle-spotify.sh"), { desc = "Spotify (toggle)" })
hl.bind("F10", hl.dsp.exec_cmd("~/.local/bin/toggle-discord.sh"), { desc = "Discord (toggle)" })
hl.bind("F9", hl.dsp.exec_cmd("~/.local/bin/toggle-whatsapp.sh"), { desc = "WhatsApp (toggle)" })
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd("~/.local/bin/keybind-cheatsheet.sh"), { desc = "Keybind cheat-sheet" })
hl.bind(mainMod .. " + Space",        hl.dsp.exec_cmd(launcher),    { desc = "App launcher" })
hl.bind(mainMod .. " + Tab",          hl.dsp.exec_cmd(windows),     { desc = "Window switcher" })
hl.bind(mainMod .. " + E",            hl.dsp.exec_cmd(fileManager), { desc = "Files" })
hl.bind(mainMod .. " + B",            hl.dsp.exec_cmd(browser),     { desc = "Web browser" })
hl.bind(mainMod .. " + A",            hl.dsp.exec_cmd("pkill -x pavucontrol || pavucontrol"), { desc = "Audio mixer (toggle)" })
hl.bind("CTRL + SHIFT + Escape",      hl.dsp.exec_cmd("pkill -f '^kitty --class btop' || kitty --class btop -e btop"), { desc = "System monitor (toggle)" })
hl.bind(mainMod .. " + V",            hl.dsp.exec_cmd(clipboard),   { desc = "Clipboard history" })
hl.bind(mainMod .. " + N",            hl.dsp.exec_cmd("swaync-client -t -sw"), { desc = "Notification centre" })
hl.bind(mainMod .. " + L",            hl.dsp.exec_cmd(lock),        { desc = "Lock screen" })
hl.bind(mainMod .. " + Escape",       hl.dsp.exec_cmd(powerMenu),   { desc = "Power menu" })
hl.bind(mainMod .. " + SHIFT + C",    hl.dsp.exec_cmd("hyprpicker -a"), { desc = "Colour picker" })
hl.bind(mainMod .. " + SHIFT + B",    hl.dsp.exec_cmd("pkill waybar; waybar"), { desc = "Restart Waybar" })

-- Screenshots (saved to ~/Pictures/Screenshots and copied to the clipboard)
hl.bind("Print",                      hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"),  { desc = "Screenshot region" })
hl.bind("SHIFT + Print",              hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"),  { desc = "Screenshot monitor" })
hl.bind("CTRL + Print",               hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"),  { desc = "Screenshot window" })
hl.bind(mainMod .. " + SHIFT + S",    hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"),           { desc = "Screenshot and annotate" })

-- Windows
hl.bind(mainMod .. " + Q",            hl.dsp.window.close(), { desc = "Close window" })
hl.bind(mainMod .. " + F",            hl.dsp.window.fullscreen({ mode = "fullscreen" }), { desc = "Fullscreen" })
hl.bind(mainMod .. " + M",            hl.dsp.window.fullscreen({ mode = "maximized" }), { desc = "Maximize" })
hl.bind(mainMod .. " + T",            hl.dsp.window.float(), { desc = "Toggle floating" })
hl.bind(mainMod .. " + P",            hl.dsp.window.pseudo(), { desc = "Toggle pseudo-tile" })
hl.bind(mainMod .. " + J",            hl.dsp.layout("togglesplit"), { desc = "Toggle split direction" })
hl.bind(mainMod .. " + SHIFT + M",    hl.dsp.exit(), { desc = "Log out of Hyprland" })

local dirs = { left = "left", right = "right", up = "up", down = "down" }
for key, dir in pairs(dirs) do
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ direction = dir }), { desc = "Focus window (" .. dir .. ")" })
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir }), { desc = "Move window (" .. dir .. ")" })
end

-- Resize the active window with SUPER + CTRL + arrows
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true, desc = "Resize window (left)" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true, desc = "Resize window (right)" })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true, desc = "Resize window (up)" })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true, desc = "Resize window (down)" })

-- Workspaces: SUPER + 1-0 to switch, SUPER + SHIFT + 1-0 to move a window there
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }), { desc = "Switch to workspace " .. key })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { desc = "Move window to workspace " .. key })
end

-- Scratchpad
hl.bind(mainMod .. " + S",            hl.dsp.workspace.toggle_special("magic"), { desc = "Scratchpad (toggle)" })
hl.bind(mainMod .. " + ALT + S",      hl.dsp.window.move({ workspace = "special:magic" }), { desc = "Move window to scratchpad" })

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }), { desc = "Next workspace" })
hl.bind(mainMod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }), { desc = "Previous workspace" })

-- Move/resize windows with SUPER + left/right mouse drag
hl.bind(mainMod .. " + mouse:272",    hl.dsp.window.drag(),   { mouse = true, desc = "Drag window (hold)" })
hl.bind(mainMod .. " + mouse:273",    hl.dsp.window.resize(), { mouse = true, desc = "Resize window (hold + drag)" })

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, desc = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, desc = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, desc = "Mute toggle" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, desc = "Mic mute toggle" })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true, desc = "Next track" })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pause" })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pause" })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true, desc = "Previous track" })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Small utility windows float in the middle of the screen
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|nwg-look|com.gabm.satty|swappy|hyprland-run|org.gnome.Calculator)$" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.4", "monitor_h*0.5" },
})

hl.window_rule({
    name      = "claude-scratchpad",
    match     = { class = "^(claude-scratchpad)$" },
    float     = true,
    center    = true,
    size      = { "monitor_w*0.5", "monitor_h*0.7" },
    workspace = "special:claude silent",
})

hl.window_rule({
    name      = "spotify-scratchpad",
    match     = { class = "^(spotify)$" },
    float     = true,
    center    = true,
    size      = { "monitor_w*0.8", "monitor_h*0.85" },
    workspace = "special:spotify silent",
})

hl.window_rule({
    name      = "discord-scratchpad",
    match     = { class = "^(discord)$" },
    float     = true,
    center    = true,
    size      = { "monitor_w*0.8", "monitor_h*0.85" },
    workspace = "special:discord silent",
})

hl.window_rule({
    name      = "whatsapp-scratchpad",
    match     = { class = "^(chrome-web.whatsapp.com__-Default)$" },
    float     = true,
    center    = true,
    size      = { "monitor_w*0.8", "monitor_h*0.85" },
    workspace = "special:whatsapp silent",
})

hl.window_rule({
    name   = "float-btop",
    match  = { class = "^btop$" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.6", "monitor_h*0.65" },
})

hl.window_rule({
    name   = "float-file-dialogs",
    match  = { title = "^(Open File|Open Folder|Save As|Save File|File Upload|Choose Files?)(.*)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
    size  = { "monitor_w*0.25", "monitor_h*0.25" },
    move  = { "monitor_w*0.74", "monitor_h*0.72" },
})

-- Don't let the screen sleep while something is fullscreen (videos, games)
hl.window_rule({
    name         = "idle-inhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Blur behind the panel, launcher, notifications and power menu
hl.layer_rule({ match = { namespace = "waybar" },   blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "rofi" },     blur = true, ignore_alpha = 0.2, dim_around = true })
hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true, animation = "fade" })
