-- ============================================================
--  Hyprland (0.56, Lua-Config) – Gegenstück zu niri/config.kdl
--
--  Gleiche Programme, Tastenkürzel, Fensterregeln und Glas-Optik wie
--  unter Niri, aber klassisches Tiling (dwindle) statt Scroll-Spalten:
--  jedes neue Fenster teilt das aktive, alles bleibt sichtbar.
--
--  Alle Tastenkürzel: Super+Shift+/
--  Doku: https://wiki.hypr.land/0.56.0/
--  Autovervollständigung (LuaLS): /run/current-system/sw/share/hypr/stubs
-- ============================================================

-- Farben aus dem Hintergrundbild (matugen, ~/.config/matugen/theme.sh).
-- Fehlt die Datei, gelten die Werte hier.
local ok, colors = pcall(require, "colors")
if not ok or type(colors) ~= "table" then
    colors = {}
end
local c = setmetatable(colors, {
    __index = {
        primary = "#a5c8ff",
        on_surface = "#e1e2e9",
        on_surface_variant = "#c3c6cf",
        surface = "#111318",
        outline = "#8d9199",
    },
})


----------------
--  Monitore  --
----------------

hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
-- LG UltraGear: VRR (FreeSync/G-Sync) nur für Spiele im Vollbild –
-- Fenster mit content = "game", siehe Fensterregeln unten
hl.monitor({ output = "DP-2", mode = "2560x1440@180", position = "1920x0", scale = 1, vrr = 3 })
-- Alles andere (Beamer, fremde Monitore): automatisch daneben
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })


--------------------
--  Umgebung      --
--------------------

-- X11-Programme mit OpenGL (Steam, ältere Spiele) auf der RTX 4060.
-- Die GPU-Reihenfolge (AQ_DRM_DEVICES) setzt nvidia.nix für die ganze Sitzung.
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")


-----------------
--  Autostart  --
-----------------

-- mako, Polkit, hypridle, KWallet und XDG-Autostart laufen als
-- systemd-Dienste (desktop.nix) – hier nur, was auch Niri selbst startet.
hl.on("hyprland.start", function()
    -- playerctld merkt sich den zuletzt aktiven Player (Medientasten, Waybar)
    hl.exec_cmd("playerctld daemon")
    hl.exec_cmd("waybar -c ~/.config/waybar/config-hyprland")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("easyeffects --service-mode --hide-window")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Zwischenablage behalten, wenn die App schließt, aus der kopiert wurde
    hl.exec_cmd("wl-clip-persist --clipboard regular")
end)


-------------------
--  Aussehen     --
-------------------

hl.config({
    general = {
        -- 8 px zwischen Fenstern und zum Rand wie in Niri
        -- (gaps_in gilt pro Fensterseite, zwischen zwei Fenstern also doppelt)
        gaps_in = 4,
        gaps_out = 8,

        -- 1px Glaskante wie in Niri
        border_size = 1,
        col = {
            active_border = c.primary .. "99",
            inactive_border = "#ffffff26",
        },

        layout = "dwindle",

        -- Tearing ist nur erlaubt, wo eine Fensterregel es anfordert (CS2)
        allow_tearing = true,

        snap = { enabled = true },
    },

    decoration = {
        -- abgerundet wie macOS (Tahoe); Hyprland erlaubt höchstens 20 px,
        -- rounding_power > 2 macht die Ecken etwas weicher (Squircle)
        rounding = 20,
        rounding_power = 2.6,

        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "#00000064",
        },

        -- Glas: Blur hinter transparenten Fenstern (Ghostty) und Leisten.
        -- 2 Durchgänge kosten auf der RTX 4060 praktisch nichts;
        -- new_optimizations lässt unveränderten Hintergrund zwischengespeichert.
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            new_optimizations = true,
            xray = false,
            noise = 0.01,
            vibrancy = 0.17,
            popups = false,
        },
    },

    -- Tabs (Super+W) im selben Glas-Stil
    group = {
        col = {
            border_active = c.primary .. "99",
            border_inactive = "#ffffff26",
        },
        groupbar = {
            font_family = "Inter",
            font_size = 11,
            height = 20,
            gradients = true,
            gradient_rounding = 10,
            rounding = 10,
            gaps_in = 4,
            gaps_out = 4,
            blur = true,
            col = {
                active = c.primary .. "59",
                inactive = "#ffffff14",
            },
            text_color = c.on_surface,
            text_color_inactive = c.on_surface_variant,
        },
    },

    animations = { enabled = true },
})

-- Kurze, weich auslaufende Animationen (Zeiten in 100 ms): flüssig auf
-- 144/180 Hz, aber nie im Weg
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "easeOutExpo", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.2, bezier = "linear", style = "fade" })
-- Arbeitsflächen gleiten senkrecht wie in Niri
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidefadevert 20%" })

hl.config({
    dwindle = {
        preserve_split = true,
        -- neue Fenster immer rechts bzw. unten (wie neue Spalten in Niri)
        force_split = 2,
        smart_resizing = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = c.surface,
        -- Fenster folgen der Maus beim Ziehen/Größe ändern 1:1, ohne Nachlauf
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        -- abgeschalteter Bildschirm (hypridle) wacht bei Maus/Taste auf
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        -- VRR nur über die Monitorregel (DP-2)
        vrr = 0,
    },

    render = {
        -- Spiele im Vollbild gehen ohne Umweg über den Compositor direkt an
        -- den Monitor (Direct Scanout) – weniger Latenz. "auto" = nur für
        -- Fenster mit content = "game"
        direct_scanout = 2,
    },

    cursor = {
        -- Mauszeiger springt nicht mit dem Tastatur-Fokus mit (wie Niri)
        no_warps = true,
    },

    binds = {
        -- wie cooldown-ms=150 in Niri: Mausrad wechselt nicht zu schnell
        scroll_event_delay = 150,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})


---------------
--  Eingabe  --
---------------

hl.config({
    input = {
        kb_layout = "us,ru,ua,de",
        kb_options = "grp:alt_shift_toggle",
        numlock_by_default = true,

        -- Fokus per Klick wie in Niri; Scrollen trifft trotzdem das
        -- Fenster unter der Maus
        follow_mouse = 2,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },

    gestures = {
        -- Wischen hinter die letzte Arbeitsfläche legt eine neue an
        workspace_swipe_create_new = true,
    },
})

-- Drei Finger hoch/runter: Arbeitsfläche wechseln (wie in Niri)
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })


---------------------
--  Übersicht      --
---------------------

-- hyprtasking (Plugin aus hyprland.nix): alle Arbeitsflächen im Raster.
-- Rechtsklick wechselt auf eine Arbeitsfläche, Fenster mit links ziehen.
hl.plugin.load("/etc/hyprland/plugins/libhyprtasking.so")

-- Die Plugin-Optionen gibt es erst, nachdem Hyprland das Plugin geladen
-- und die Config neu eingelesen hat
if hl.plugin.hyprtasking then
    hl.config({
        plugin = {
            hyprtasking = {
                layout = "grid",
                gap_size = 16,
                border_size = 2,
                bg_color = 0xff000000 + tonumber(c.surface:sub(2, 7), 16),
                close_overview_on_reload = true,
                gestures = { enabled = false },
                grid = {
                    rows = 3,
                    cols = 3,
                    gaps_use_aspect_ratio = true,
                },
            },
        },
    })
end

local function overview()
    local ht = hl.plugin.hyprtasking
    if ht then
        ht.toggle("all")
    end
end


---------------------------------
--  Fensterregeln & Leisten    --
---------------------------------

-- Hinweis: Regeln prüfen den ganzen Namen (FullMatch), "steam_app_.*"
-- statt "^steam_app_" wie in Niri

-- Maximieren-Anfragen ignorieren – Fenster bleiben im Tiling
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Bildschirm nicht sperren/abschalten, solange ein Fenster im Vollbild
-- ist (Videos, Spiele)
hl.window_rule({ name = "idle-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Drag & Drop aus X11-Apps (Steam) nicht verschlucken
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name = "firefox-pip",
    match = { class = ".*firefox", title = "Picture-in-Picture" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
})

hl.window_rule({
    name = "float-apps",
    match = { class = "org\\.telegram\\.desktop|discord|com\\.gabm\\.satty" },
    float = true,
})

-- Passwort-/2FA-Apps: schwebend und beim Bildschirmteilen geschwärzt
hl.window_rule({
    name = "secrets",
    match = { class = "io\\.ente\\.auth|Bitwarden" },
    float = true,
    no_screen_share = true,
})

hl.window_rule({ name = "gamescope-fullscreen", match = { class = "gamescope" }, fullscreen = true })

-- Spiele (CS2, Steam, gamescope, Roblox über Sober): als Spiel markieren →
-- VRR auf dem LG und Direct Scanout
hl.window_rule({
    name = "games",
    match = { class = "steam_app_.*|cs2|gamescope|org\\.vinegarhq\\.Sober" },
    content = "game",
})

-- CS2: Tearing statt auf den nächsten Refresh zu warten – niedrigste
-- Eingabelatenz bei fps_max 0. Unter 180 FPS greift weiter VRR.
hl.window_rule({ name = "cs2-tearing", match = { class = "cs2" }, immediate = true })

-- Glas-Leisten: Blur hinter halbdurchsichtigen Flächen, die ganz
-- durchsichtigen Ecken (Rundung) bleiben frei (ignore_alpha)
hl.layer_rule({ name = "waybar-glass", match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ name = "rofi-glass", match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ name = "fuzzel-glass", match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ name = "wlogout-glass", match = { namespace = "logout_dialog" }, blur = true })
-- Benachrichtigungen: Glas, beim Bildschirmteilen nicht mitsenden
hl.layer_rule({
    name = "mako-glass",
    match = { namespace = "notifications" },
    blur = true,
    ignore_alpha = 0.1,
    no_screen_share = true,
})
-- Bereichsauswahl (slurp) ohne Ein-/Ausblenden – sonst landet sie halb im Screenshot
hl.layer_rule({ name = "slurp-no-anim", match = { namespace = "selection" }, no_anim = true })


---------------------
--  Tastenkürzel   --
---------------------

local function key(k)
    return "SUPER + " .. k
end

local function bind(keys, action, description, opts)
    opts = opts or {}
    opts.description = description
    return hl.bind(keys, action, opts)
end

-- Alle Fenster der Arbeitsfläche gleichmäßig aufteilen (jede Teilung 50/50)
local function even_split()
    local ws = hl.get_active_workspace()
    if not ws then
        return
    end
    local windows = hl.get_windows({ workspace = ws, floating = false, mapped = true })
    if #windows < 2 then
        return
    end
    local active = hl.get_active_window()
    for _, w in ipairs(windows) do
        hl.dispatch(hl.dsp.focus({ window = w }))
        hl.dispatch(hl.dsp.layout("splitratio 1 exact"))
    end
    if active then
        hl.dispatch(hl.dsp.focus({ window = active }))
    end
end

-- Teilung in festen Schritten wie Niris Spaltenbreiten (⅓, ½, ⅔)
local split_presets = { 0.667, 1.0, 1.333 }
local split_index = {}
local function cycle_split(step)
    return function()
        local w = hl.get_active_window()
        if not w or w.floating then
            return
        end
        local i = ((split_index[w.address] or 2) - 1 + step) % #split_presets + 1
        split_index[w.address] = i
        hl.dispatch(hl.dsp.layout("splitratio " .. split_presets[i] .. " exact"))
    end
end

-- Fenster um einen Anteil der Monitorgröße ändern (−10 % / +10 %)
local function resize(dx, dy)
    return function()
        local m = hl.get_active_monitor()
        if m then
            hl.dispatch(hl.dsp.window.resize({ x = m.width * dx, y = m.height * dy, relative = true }))
        end
    end
end

-- Fokus zwischen schwebenden und gekachelten Fenstern wechseln
local function toggle_float_focus()
    local w = hl.get_active_window()
    if w and w.floating then
        hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
    end
end

-- Programme
bind(key("SHIFT + slash"), hl.dsp.exec_cmd("hypr-keybinds"), "Alle Tastenkürzel anzeigen")
bind(key("T"), hl.dsp.exec_cmd("ghostty"), "Terminal (Ghostty)")
bind(key("D"), hl.dsp.exec_cmd("rofi -show drun"), "Programme starten (Rofi)")
bind(key("space"), hl.dsp.exec_cmd("rofi -show drun"))
bind(key("SHIFT + L"), hl.dsp.exec_cmd("pidof hyprlock || hyprlock"), "Bildschirm sperren")

-- Lautstärke, Medien, Helligkeit (auch auf dem Sperrbildschirm)
local media = { locked = true }
local held = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01+ -l 1.0"), nil, held)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01-"), nil, held)
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), nil, media)
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), nil, media)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), nil, media)
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), nil, media)
bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), nil, media)
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), nil, media)
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), nil, media)
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl --class=backlight set +10%"), nil, held)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 10%-"), nil, held)

-- Übersicht, Fenster schließen
bind(key("O"), overview, "Übersicht aller Arbeitsflächen")
bind("Escape", function()
    local ht = hl.plugin.hyprtasking
    if ht and ht.is_active() then
        ht.toggle("all")
    end
end, nil, { non_consuming = true })
bind(key("Q"), hl.dsp.window.close(), "Fenster schließen")

-- Fokus und Verschieben: Pfeile oder H/J/K/L
--   Super        Fokus
--   Super+Strg   Fenster verschieben
--   Super+Shift  Fokus auf anderen Monitor
--   Super+Shift+Strg  Fenster auf anderen Monitor
local directions = {
    { "left", "H", "left", "l", "links" },
    { "down", "J", "down", "d", "unten" },
    { "up", "K", "up", "u", "oben" },
    { "right", "L", "right", "r", "rechts" },
}
for _, d in ipairs(directions) do
    local arrow, letter, dir, mon, name = d[1], d[2], d[3], d[4], d[5]
    for _, k in ipairs({ arrow, letter }) do
        local first = k == arrow
        bind(key(k), hl.dsp.focus({ direction = dir }), first and ("Fokus nach " .. name) or nil)
        bind(key("CTRL + " .. k), hl.dsp.window.move({ direction = dir }), first and ("Fenster nach " .. name) or nil)
        -- Super+Shift+L sperrt den Bildschirm (wie in Niri)
        if k ~= "L" then
            bind(key("SHIFT + " .. k), hl.dsp.focus({ monitor = mon }), first and ("Monitor " .. name) or nil)
        end
        bind(key("SHIFT + CTRL + " .. k), hl.dsp.window.move({ monitor = mon }),
            first and ("Fenster auf Monitor " .. name) or nil)
    end
end

-- Arbeitsflächen: nächste/vorige auf diesem Monitor (auch leere, wie in Niri)
bind(key("Page_Down"), hl.dsp.focus({ workspace = "r+1" }), "Nächste Arbeitsfläche")
bind(key("Page_Up"), hl.dsp.focus({ workspace = "r-1" }), "Vorige Arbeitsfläche")
bind(key("U"), hl.dsp.focus({ workspace = "r+1" }))
bind(key("I"), hl.dsp.focus({ workspace = "r-1" }))
bind(key("CTRL + Page_Down"), hl.dsp.window.move({ workspace = "r+1" }), "Fenster eine Arbeitsfläche weiter")
bind(key("CTRL + Page_Up"), hl.dsp.window.move({ workspace = "r-1" }), "Fenster eine Arbeitsfläche zurück")
bind(key("CTRL + U"), hl.dsp.window.move({ workspace = "r+1" }))
bind(key("CTRL + I"), hl.dsp.window.move({ workspace = "r-1" }))
bind(key("mouse_down"), hl.dsp.focus({ workspace = "r+1" }), "Arbeitsfläche wechseln")
bind(key("mouse_up"), hl.dsp.focus({ workspace = "r-1" }))
bind(key("CTRL + mouse_down"), hl.dsp.window.move({ workspace = "r+1" }))
bind(key("CTRL + mouse_up"), hl.dsp.window.move({ workspace = "r-1" }))

for i = 1, 9 do
    local first = i == 1
    bind(key(tostring(i)), hl.dsp.focus({ workspace = i }), first and "Arbeitsfläche 1–9" or nil)
    bind(key("CTRL + " .. i), hl.dsp.window.move({ workspace = i }),
        first and "Fenster auf Arbeitsfläche 1–9 (mitgehen)" or nil)
    bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i, follow = false }),
        first and "Fenster auf Arbeitsfläche 1–9 (hierbleiben)" or nil)
end

-- Layout (dwindle)
bind(key("R"), cycle_split(1), "Teilung ⅓ → ½ → ⅔")
bind(key("SHIFT + R"), cycle_split(-1), "Teilung ⅔ → ½ → ⅓")
bind(key("CTRL + R"), hl.dsp.layout("splitratio 1 exact"), "Teilung zurück auf ½")
bind(key("S"), hl.dsp.layout("togglesplit"), "Teilung drehen (nebeneinander ↔ übereinander)")
bind(key("CTRL + S"), hl.dsp.layout("swapsplit"), "Seiten der Teilung tauschen")
bind(key("E"), even_split, "Alle Fenster gleichmäßig aufteilen")

bind(key("minus"), resize(-0.1, 0), "Fenster schmaler", { repeating = true })
bind(key("equal"), resize(0.1, 0), "Fenster breiter", { repeating = true })
bind(key("SHIFT + minus"), resize(0, -0.1), "Fenster niedriger", { repeating = true })
bind(key("SHIFT + equal"), resize(0, 0.1), "Fenster höher", { repeating = true })

bind(key("F"), hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximieren (Leiste bleibt)")
bind(key("M"), hl.dsp.window.fullscreen({ mode = "maximized" }))
bind(key("SHIFT + F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Vollbild")

bind(key("V"), hl.dsp.window.float({ action = "toggle" }), "Schwebend ↔ gekachelt")
bind(key("SHIFT + V"), toggle_float_focus, "Fokus: schwebend ↔ gekachelt")
bind(key("C"), hl.dsp.window.center(), "Schwebendes Fenster zentrieren")

-- Tabs (wie Niris Tab-Spalten): Fenster in einer Gruppe übereinander
bind(key("W"), hl.dsp.group.toggle(), "Tabs an/aus")
bind(key("bracketleft"), hl.dsp.group.prev(), "Vorheriger Tab")
bind(key("bracketright"), hl.dsp.group.next(), "Nächster Tab")
bind(key("comma"), hl.dsp.window.move({ into_or_create_group = "left" }), "Fenster in Tabs links einreihen")
bind(key("period"), hl.dsp.window.move({ out_of_group = true }), "Fenster aus Tabs lösen")

-- Maus: Super + ziehen verschiebt, Super + Rechtsklick ändert die Größe
bind(key("mouse:272"), hl.dsp.window.drag(), "Fenster verschieben", { mouse = true })
bind(key("mouse:273"), hl.dsp.window.resize(), "Fenstergröße ändern", { mouse = true })

-- Screenshots
-- Wie Spectacle: Bereich wählen → zeichnen → Enter kopiert und speichert
bind(key("SHIFT + S"), hl.dsp.exec_cmd("screenshot-edit"), "Screenshot mit Zeichnen (Satty)")
-- Ohne Zeichnen: Bereich → Clipboard + ~/Screenshots
bind("Print", hl.dsp.exec_cmd("screenshot"), "Screenshot eines Bereichs")
