-- ============================================================
--  Hyprland (0.56, Lua) – 1:1 übersetzt aus niri/config.kdl
--
--  Gleiche Reihenfolge, gleiche Tasten, gleiche Regeln wie Niri.
--  Nur das Tiling ist anders (dwindle statt Scroll-Spalten): Niri-Aktionen
--  für Spalten machen hier das Gleiche mit dem Fenster bzw. der Teilung.
--  Was Hyprland nicht kann, steht als Kommentar an der Stelle.
--
--  Doku: https://wiki.hypr.land/0.56.0/
-- ============================================================

-- Farben aus dem Hintergrundbild (matugen, ~/.config/matugen/theme.sh).
-- Niri: include "~/.config/niri/colors.kdl" (dort am Ende)
local ok, colors = pcall(require, "colors")
if not ok or type(colors) ~= "table" then
    colors = {}
end
local c = setmetatable(colors, { __index = { primary = "#a5c8ff", surface = "#111318" } })


-- ── input ───────────────────────────────────────────────────

hl.config({
    input = {
        kb_layout = "us,ru,ua,de",
        kb_options = "grp:alt_shift_toggle",

        numlock_by_default = true,

        touchpad = {
            tap_to_click = true,
            natural_scroll = true,
        },

        -- Niri: Fokus per Klick, Scrollen trifft das Fenster unter der Maus
        follow_mouse = 2,
    },
})


-- ── output ──────────────────────────────────────────────────

hl.monitor({ output = "eDP-1", mode = "1920x1080@144.003", position = "0x0", scale = 1, transform = 0 })

-- VRR (FreeSync/G-Sync) nur für Fenster mit passender window-rule (Spiele):
-- vrr = 3 heißt „nur im Vollbild für Fenster mit content = game“
hl.monitor({ output = "DP-2", mode = "2560x1440@179.959", position = "1920x0", scale = 1, vrr = 3 })


-- ── layout ──────────────────────────────────────────────────

hl.config({
    general = {
        layout = "dwindle",

        -- gaps 8 (gaps_in gilt pro Fensterseite → 8 zwischen zwei Fenstern)
        gaps_in = 4,
        gaps_out = 8,

        -- focus-ring off, border on width 1
        border_size = 1,
        col = {
            active_border = c.primary .. "99",
            inactive_border = "#ffffff26",
        },

        -- nur für die cs2-Regel unten (Niri kennt kein Tearing)
        allow_tearing = true,

        -- Fokus springt am Rand nicht ans andere Ende (wie Niri)
        no_focus_fallback = true,
    },

    decoration = {
        -- window-rule geometry-corner-radius 24 (unten): Hyprland erlaubt
        -- höchstens 20, clip-to-geometry macht Hyprland immer
        rounding = 20,
        rounding_power = 2,

        -- shadow: softness 50, offset 0 0, color #00000064
        -- (spread 5 und draw-behind-window gibt es in Hyprland nicht)
        shadow = {
            enabled = true,
            range = 50,
            render_power = 3,
            offset = { 0, 0 },
            color = "#00000064",
        },

        -- Blur nur für Ghostty, Waybar, mako, wlogout, Rofi –
        -- siehe window-rule/layer-rule unten (xray false)
        -- Wie Niri: 3 Durchgänge statt 1, kein Kontrast-Abschlag (sonst
        -- Grauschleier), dazu kräftigere Farben dahinter wie Liquid Glass
        blur = {
            enabled = true,
            xray = false,
            size = 5,
            passes = 3,
            noise = 0.02,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.35,
            vibrancy_darkness = 0.2,
            -- Rechtsklick-Menüs usw. auch aus Glas
            popups = true,
        },
    },

    dwindle = {
        -- center-focused-column "never", default-column-width 0.5:
        -- neue Fenster teilen das aktive 50/50 und kommen rechts/unten hin,
        -- wie neue Spalten in Niri
        preserve_split = true,
        force_split = 2,
    },

    binds = {
        -- Fokus und Verschieben gehen am Rand nicht auf den anderen Monitor
        -- (dafür gibt es wie in Niri Mod+Shift bzw. Mod+Shift+Ctrl)
        window_direction_monitor_fallback = false,
        -- Mod+WheelScroll… cooldown-ms=150
        scroll_event_delay = 150,
    },
})


-- ── prefer-no-csd ───────────────────────────────────────────
-- Hyprland zeichnet keine Titelleisten; Apps, die es unterstützen,
-- lassen ihre eigenen weg (wie unter Niri).


-- ── cursor ──────────────────────────────────────────────────

hl.env("XCURSOR_THEME", "catppuccin-mocha-mauve-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.config({
    cursor = {
        -- Niri springt mit dem Mauszeiger nicht zum fokussierten Fenster
        no_warps = true,
    },
})


-- ── spawn-at-startup ────────────────────────────────────────

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
    -- (unter Wayland gehört der Inhalt sonst der App)
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    -- Nur Hyprland: Alt+Tab mit Fenster-Vorschau (Niri hat das eingebaut).
    -- hyprshell legt Alt+Tab selbst an, Config: ~/.config/hyprshell;
    -- HYPRSHELL_EXPERIMENTAL=1 schaltet die Vorschau statt App-Icons ein
    hl.exec_cmd("env HYPRSHELL_EXPERIMENTAL=1 hyprshell run -c ~/.config/hyprshell/config.toml")
end)


-- ── hotkey-overlay ──────────────────────────────────────────
-- skip-at-startup: Hyprland zeigt beim Start nichts an.
-- Mod+Shift+/ öffnet die Liste (hypr-keybinds, siehe binds).


-- ── screenshot-path ─────────────────────────────────────────
-- "~/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png" – so speichern
-- auch screenshot (Druck) und screenshot-edit (Mod+Shift+S).


-- ── animations ──────────────────────────────────────────────
-- Niris Standard-Animationen (animations {} ist dort leer):
--   workspace-switch   spring damping-ratio=1.0 stiffness=1000
--   window-movement / window-resize  spring damping-ratio=1.0 stiffness=800
--   window-open        150 ms ease-out-expo, wächst von 50 % + einblenden
--   window-close       150 ms ease-out-quad, schrumpft auf 50 % + ausblenden
-- Rahmenfarbe, Leisten (Waybar, Rofi, mako) und Popups animiert Niri nicht.
-- Dämpfung = damping-ratio · 2·√(stiffness · mass)
--
-- Etwas weicher als Niri: niedrigere Steifigkeit (600/750 statt 800/1000),
-- Dämpfung bleibt 1.0 (kein Nachschwingen); öffnen/schließen 200 ms und
-- popin 70 %; Leisten blenden kurz ein statt aufzuspringen

hl.curve("spring600", { type = "spring", mass = 1, stiffness = 600, dampening = 48.9898 })
hl.curve("spring750", { type = "spring", mass = 1, stiffness = 750, dampening = 54.7723 })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("easeOutQuad", { type = "bezier", points = { { 0.5, 1 }, { 0.89, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2.5, spring = "spring600" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "easeOutExpo", style = "popin 70%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "easeOutQuad", style = "popin 70%" })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "easeOutQuad" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, spring = "spring750", style = "slidevert" })
-- Rofi wächst zusätzlich leicht (layer-rule unten)
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "easeOutExpo", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.5, bezier = "easeOutExpo" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "easeOutQuad" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "zoomFactor", enabled = false })
hl.animation({ leaf = "monitorAdded", enabled = false })


-- ── window-rule ─────────────────────────────────────────────
-- Hyprland prüft den ganzen Namen: "steam_app_.*" statt "^steam_app_",
-- ".*firefox" statt "firefox$". Mehrere match-Zeilen → a|b|c.

-- org.wezfurlong.wezterm default-column-width {}: in dwindle ohne Bedeutung

hl.window_rule({
    name = "firefox-pip",
    match = { class = ".*firefox", title = "Picture-in-Picture" },
    float = true,
})

hl.window_rule({
    name = "telegram",
    match = { class = "org\\.telegram\\.desktop" },
    float = true,
})

hl.window_rule({
    name = "gamescope",
    match = { class = "gamescope" },
    fullscreen = true,
})

-- Spiele: VRR auf dem LG (CS2, Steam-Spiele, gamescope, Roblox über Sober)
hl.window_rule({
    name = "games-vrr",
    match = { class = "steam_app_.*|cs2|gamescope|org\\.vinegarhq\\.Sober" },
    content = "game",
})

-- is-window-cast-target (roter Rahmen beim Teilen): gibt es in Hyprland nicht

hl.window_rule({
    name = "discord",
    match = { class = "discord" },
    float = true,
})

hl.window_rule({
    name = "satty",
    match = { class = "com\\.gabm\\.satty" },
    float = true,
})

hl.window_rule({
    name = "ente-auth",
    match = { class = "io\\.ente\\.auth" },
    float = true,
    no_screen_share = true,
})

hl.window_rule({
    name = "bitwarden",
    match = { class = "Bitwarden" },
    float = true,
    no_screen_share = true,
})

-- abgerundete Fenster wie in macOS (Tahoe): rounding = 20 oben

-- Spiele ohne Rundung – sonst muss Hyprland jedes Bild neu zeichnen statt
-- es direkt an den Monitor zu geben (Direct Scanout, render unten)
hl.window_rule({
    name = "games-no-rounding",
    match = { class = "steam_app_.*|cs2|gamescope|org\\.vinegarhq\\.Sober" },
    rounding = 0,
})

-- Ghostty: Liquid-Glass-Terminal (Blur hinter dem transparenten Hintergrund).
-- In Hyprland ist Blur global, deshalb: alle anderen Fenster ohne Blur
hl.window_rule({
    name = "blur-only-ghostty",
    match = { class = "negative:com\\.mitchellh\\.ghostty" },
    no_blur = true,
})

-- Nur Hyprland: CS2 darf tearen (niedrigste Latenz bei fps_max 0)
hl.window_rule({
    name = "cs2-tearing",
    match = { class = "cs2" },
    immediate = true,
})

-- Nur Hyprland: Drag & Drop aus X11-Apps (Steam) nicht verschlucken
hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})


-- ── layer-rule ──────────────────────────────────────────────
-- Rundung und Schatten der Leisten kann Hyprland nicht setzen; ignore_alpha
-- lässt den Blur an den durchsichtigen Ecken weg, dadurch folgt er der Rundung

-- gleiche Rundung wie window#waybar in waybar/style.css
hl.layer_rule({ name = "waybar", match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.1 })

-- Mako: Glas-Benachrichtigungen, beim Bildschirmteilen nicht mitsenden
hl.layer_rule({
    name = "notifications",
    match = { namespace = "notifications" },
    no_screen_share = true,
    blur = true,
    ignore_alpha = 0.1,
})

-- wlogout: Glas-Hintergrund
hl.layer_rule({ name = "logout_dialog", match = { namespace = "logout_dialog" }, blur = true })

-- slurp (Bereich für screenshot/screenshot-edit) sofort weg, sonst fotografiert
-- grim den ausblendenden Rahmen und Schleier mit
hl.layer_rule({ name = "slurp", match = { namespace = "selection" }, no_anim = true })

-- hyprshell (Alt+Tab): Glas wie Rofi, Radius = .monitor in hyprshell/styles.css
hl.layer_rule({ name = "hyprshell_switch", match = { namespace = "hyprshell_switch" }, blur = true, ignore_alpha = 0.1 })

-- Rofi (Spotlight-Starter): Radius = border-radius in rofi/spotlight.rasi
-- und geht wie Spotlight leicht wachsend auf
hl.layer_rule({
    name = "rofi",
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "popin 90%",
})


-- ── binds ───────────────────────────────────────────────────
-- Niri wiederholt gehaltene Tasten (außer repeat=false) – hier ebenso.
-- Beschreibungen = Titel aus Niris Hotkey-Overlay (Mod+Shift+/).

local function key(k)
    return "SUPER + " .. k
end

local function bind(keys, action, opts)
    opts = opts or {}
    if opts.repeating == nil then
        opts.repeating = true
    end
    return hl.bind(keys, action, opts)
end

local function title(t, opts)
    opts = opts or {}
    opts.description = t
    return opts
end

-- Hilfen: Niri-Aktionen für Spalten/Arbeitsflächen in dwindle

local function active_workspace_windows()
    local ws = hl.get_active_workspace()
    if not ws then
        return {}
    end
    return hl.get_windows({ workspace = ws, floating = false, mapped = true })
end

-- Liegt ein gekacheltes Fenster in dieser Richtung neben w?
local function has_neighbor(w, dir)
    local a, s = w.at, w.size
    for _, o in ipairs(active_workspace_windows()) do
        if o.address ~= w.address then
            local b, t = o.at, o.size
            local overlap_x = b.x < a.x + s.x and a.x < b.x + t.x
            local overlap_y = b.y < a.y + s.y and a.y < b.y + t.y
            if (dir == "down" and overlap_x and b.y >= a.y + s.y)
                or (dir == "up" and overlap_x and b.y + t.y <= a.y)
                or (dir == "right" and overlap_y and b.x >= a.x + s.x)
                or (dir == "left" and overlap_y and b.x + t.x <= a.x) then
                return true
            end
        end
    end
    return false
end

-- focus-workspace-down/up: auf diesem Monitor, unter der leeren
-- Arbeitsfläche ist Schluss (wie in Niri)
local function focus_workspace(step)
    return function()
        local ws = hl.get_active_workspace()
        if not ws or (step > 0 and ws.is_empty) or (step < 0 and ws.id <= 1) then
            return
        end
        hl.dispatch(hl.dsp.focus({ workspace = step > 0 and "r+1" or "r-1" }))
    end
end

-- move-column-to-workspace-down/up
local function move_to_workspace(step)
    return function()
        local ws = hl.get_active_workspace()
        if not ws or (step < 0 and ws.id <= 1) then
            return
        end
        hl.dispatch(hl.dsp.window.move({ workspace = step > 0 and "r+1" or "r-1" }))
    end
end

-- focus-window-or-workspace-down/up: Fenster darunter/darüber, in Tabs der
-- nächste Tab, sonst die nächste Arbeitsfläche
local function focus_window_or_workspace(dir, step)
    return function()
        local w = hl.get_active_window()
        if w then
            local g = w.group
            if g and g.size > 1 then
                if step > 0 and g.current_index < g.size then
                    return hl.dispatch(hl.dsp.group.next())
                elseif step < 0 and g.current_index > 1 then
                    return hl.dispatch(hl.dsp.group.prev())
                end
            end
            local result = hl.dispatch(hl.dsp.focus({ direction = dir }))
            if not result or result.ok ~= false then
                return
            end
        end
        focus_workspace(step)()
    end
end

-- move-window-down-or-to-workspace-down/up
local function move_window_or_to_workspace(dir, step)
    return function()
        local w = hl.get_active_window()
        if not w then
            return
        end
        if not w.floating and has_neighbor(w, dir) then
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
        else
            move_to_workspace(step)()
        end
    end
end

-- move-workspace-down/up: Arbeitsfläche mit der darunter/darüber tauschen
local function move_workspace(step)
    return function()
        local ws = hl.get_active_workspace()
        if not ws or ws.special or (step > 0 and ws.is_empty) then
            return
        end
        local from, to = ws.id, ws.id + step
        if to < 1 then
            return
        end
        local tmp = 999999
        if hl.get_workspace(to) then
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = to, id = tmp }))
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = from, id = to }))
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = tmp, id = from }))
        else
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = from, id = to }))
        end
    end
end

-- focus-column-first/last: Fenster ganz links/rechts
local function edge_window(last)
    local best
    for _, w in ipairs(active_workspace_windows()) do
        local a = w.at
        local b = best and best.at
        if not best or (last and (a.x > b.x or (a.x == b.x and a.y > b.y)))
            or (not last and (a.x < b.x or (a.x == b.x and a.y < b.y))) then
            best = w
        end
    end
    return best
end

local function focus_edge(last)
    return function()
        local w = edge_window(last)
        if w then
            hl.dispatch(hl.dsp.focus({ window = w }))
        end
    end
end

-- move-column-to-first/last: mit dem Fenster ganz links/rechts tauschen
local function move_to_edge(last)
    return function()
        local a, w = hl.get_active_window(), edge_window(last)
        if a and w and a.address ~= w.address then
            hl.dispatch(hl.dsp.window.swap({ target = w }))
        end
    end
end

-- consume-or-expel-window-left/right: in Tabs (Gruppe) einreihen bzw. lösen
local function consume_or_expel(dir)
    return function()
        local w = hl.get_active_window()
        if not w then
            return
        end
        if w.group and w.group.size > 1 then
            hl.dispatch(hl.dsp.window.move({ out_of_group = dir }))
        else
            hl.dispatch(hl.dsp.window.move({ into_or_create_group = dir }))
        end
    end
end

-- switch-preset-column-width / -window-height: Teilung ⅓ → ½ → ⅔
-- (preset-column-widths 0.33333 0.5 0.66667)
local presets = { 0.66667, 1.0, 1.33333 } -- splitratio: 1.0 = 50/50
local preset_index = {}
local function switch_preset(step)
    return function()
        local w = hl.get_active_window()
        if not w or w.floating then
            return
        end
        local i = ((preset_index[w.address] or 2) - 1 + step) % #presets + 1
        preset_index[w.address] = i
        hl.dispatch(hl.dsp.layout("splitratio " .. presets[i] .. " exact"))
    end
end

-- Split Windows Evenly: jede Teilung auf 50/50
local function split_evenly()
    local windows = active_workspace_windows()
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

-- set-column-width / set-window-height "±10%"
local function resize(dx, dy)
    return function()
        local m = hl.get_active_monitor()
        if m then
            hl.dispatch(hl.dsp.window.resize({ x = m.width * dx, y = m.height * dy, relative = true }))
        end
    end
end

local function switch_focus_floating_tiling()
    local w = hl.get_active_window()
    if w and w.floating then
        hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
    end
end

-- toggle-overview: Plugin hyprtasking (hyprland.nix)
local function toggle_overview()
    local ht = hl.plugin.hyprtasking
    if ht then
        ht.toggle("all")
    end
end


bind(key("SHIFT + slash"), hl.dsp.exec_cmd("hypr-keybinds"), title("Show Important Hotkeys"))

bind(key("T"), hl.dsp.exec_cmd("ghostty"), title("Open a Terminal: ghostty"))
bind(key("D"), hl.dsp.exec_cmd("rofi -show drun"), title("Run an Application: rofi"))
bind(key("space"), hl.dsp.exec_cmd("rofi -show drun"))
bind(key("SHIFT + L"), hl.dsp.exec_cmd("hyprlock"), title("Lock the Screen: hyprlock"))

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01+ -l 1.0"), { locked = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01-"), { locked = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })

bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl --class=backlight set +10%"), { locked = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 10%-"), { locked = true })

bind(key("O"), toggle_overview, title("Open the Overview", { repeating = false }))
-- Esc schließt die Übersicht (wie in Niri)
bind("Escape", function()
    local ht = hl.plugin.hyprtasking
    if ht and ht.is_active() then
        ht.toggle("all")
    end
end, { non_consuming = true, repeating = false })

bind(key("Q"), hl.dsp.window.close(), title("Close Focused Window", { repeating = false }))

bind(key("left"), hl.dsp.focus({ direction = "left" }), title("Focus Column to the Left"))
bind(key("down"), focus_window_or_workspace("down", 1))
bind(key("up"), focus_window_or_workspace("up", -1))
bind(key("right"), hl.dsp.focus({ direction = "right" }), title("Focus Column to the Right"))
bind(key("H"), hl.dsp.focus({ direction = "left" }))
bind(key("J"), focus_window_or_workspace("down", 1))
bind(key("K"), focus_window_or_workspace("up", -1))
bind(key("L"), hl.dsp.focus({ direction = "right" }))

bind(key("CTRL + left"), hl.dsp.window.move({ direction = "left" }), title("Move Column Left"))
bind(key("CTRL + down"), move_window_or_to_workspace("down", 1))
bind(key("CTRL + up"), move_window_or_to_workspace("up", -1))
bind(key("CTRL + right"), hl.dsp.window.move({ direction = "right" }), title("Move Column Right"))
bind(key("CTRL + H"), hl.dsp.window.move({ direction = "left" }))
bind(key("CTRL + J"), move_window_or_to_workspace("down", 1))
bind(key("CTRL + K"), move_window_or_to_workspace("up", -1))
bind(key("CTRL + L"), hl.dsp.window.move({ direction = "right" }))


bind(key("Home"), focus_edge(false))
bind(key("End"), focus_edge(true))
bind(key("CTRL + Home"), move_to_edge(false))
bind(key("CTRL + End"), move_to_edge(true))

bind(key("SHIFT + left"), hl.dsp.focus({ monitor = "l" }))
bind(key("SHIFT + down"), hl.dsp.focus({ monitor = "d" }))
bind(key("SHIFT + up"), hl.dsp.focus({ monitor = "u" }))
bind(key("SHIFT + right"), hl.dsp.focus({ monitor = "r" }))
bind(key("SHIFT + H"), hl.dsp.focus({ monitor = "l" }))
bind(key("SHIFT + J"), hl.dsp.focus({ monitor = "d" }))
bind(key("SHIFT + K"), hl.dsp.focus({ monitor = "u" }))

bind(key("SHIFT + CTRL + left"), hl.dsp.window.move({ monitor = "l" }))
bind(key("SHIFT + CTRL + down"), hl.dsp.window.move({ monitor = "d" }))
bind(key("SHIFT + CTRL + up"), hl.dsp.window.move({ monitor = "u" }))
bind(key("SHIFT + CTRL + right"), hl.dsp.window.move({ monitor = "r" }))
bind(key("SHIFT + CTRL + H"), hl.dsp.window.move({ monitor = "l" }))
bind(key("SHIFT + CTRL + J"), hl.dsp.window.move({ monitor = "d" }))
bind(key("SHIFT + CTRL + K"), hl.dsp.window.move({ monitor = "u" }))
bind(key("SHIFT + CTRL + L"), hl.dsp.window.move({ monitor = "r" }))



bind(key("Page_Down"), focus_workspace(1), title("Switch Workspace Down"))
bind(key("Page_Up"), focus_workspace(-1), title("Switch Workspace Up"))
bind(key("U"), focus_workspace(1))
bind(key("I"), focus_workspace(-1))
bind(key("CTRL + Page_Down"), move_to_workspace(1), title("Move Column to Workspace Down"))
bind(key("CTRL + Page_Up"), move_to_workspace(-1), title("Move Column to Workspace Up"))
bind(key("CTRL + U"), move_to_workspace(1))
bind(key("CTRL + I"), move_to_workspace(-1))


bind(key("SHIFT + Page_Down"), move_workspace(1))
bind(key("SHIFT + Page_Up"), move_workspace(-1))
bind(key("SHIFT + U"), move_workspace(1))
bind(key("SHIFT + I"), move_workspace(-1))

bind(key("mouse_down"), focus_workspace(1), { repeating = false })
bind(key("mouse_up"), focus_workspace(-1), { repeating = false })
bind(key("CTRL + mouse_down"), move_to_workspace(1), { repeating = false })
bind(key("CTRL + mouse_up"), move_to_workspace(-1), { repeating = false })

bind(key("mouse_right"), hl.dsp.focus({ direction = "right" }), { repeating = false })
bind(key("mouse_left"), hl.dsp.focus({ direction = "left" }), { repeating = false })
bind(key("CTRL + mouse_right"), hl.dsp.window.move({ direction = "right" }), { repeating = false })
bind(key("CTRL + mouse_left"), hl.dsp.window.move({ direction = "left" }), { repeating = false })

bind(key("SHIFT + mouse_down"), hl.dsp.focus({ direction = "right" }), { repeating = false })
bind(key("SHIFT + mouse_up"), hl.dsp.focus({ direction = "left" }), { repeating = false })
bind(key("CTRL + SHIFT + mouse_down"), hl.dsp.window.move({ direction = "right" }), { repeating = false })
bind(key("CTRL + SHIFT + mouse_up"), hl.dsp.window.move({ direction = "left" }), { repeating = false })


for i = 1, 9 do
    bind(key(tostring(i)), hl.dsp.focus({ workspace = i }))
end
for i = 1, 9 do
    bind(key("CTRL + " .. i), hl.dsp.window.move({ workspace = i }))
end



bind(key("bracketleft"), consume_or_expel("left"), title("Consume or Expel Window Left"))
bind(key("bracketright"), consume_or_expel("right"), title("Consume or Expel Window Right"))

bind(key("comma"), hl.dsp.window.move({ into_or_create_group = "right" }))
bind(key("period"), hl.dsp.window.move({ out_of_group = "right" }))

bind(key("R"), switch_preset(1), title("Switch Preset Column Widths"))
bind(key("SHIFT + R"), switch_preset(-1))

bind(key("CTRL + SHIFT + R"), switch_preset(1))
bind(key("CTRL + R"), hl.dsp.layout("splitratio 1 exact"))

bind(key("F"), hl.dsp.window.fullscreen({ mode = "maximized" }), title("Maximize Column"))
bind(key("SHIFT + F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }))

bind(key("M"), hl.dsp.window.fullscreen({ mode = "maximized" }))

-- expand-column-to-available-width: in dwindle füllt jedes Fenster seinen
-- Platz schon aus – daher wie Maximieren
bind(key("CTRL + F"), hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Alle Fenster auf dem Bildschirm gleichmäßig aufteilen
bind(key("E"), split_evenly, title("Split Windows Evenly"))

-- center-column / center-visible-columns: zentriert schwebende Fenster
bind(key("C"), hl.dsp.window.center())

bind(key("CTRL + C"), hl.dsp.window.center())

bind(key("minus"), resize(-0.1, 0))
bind(key("equal"), resize(0.1, 0))

bind(key("SHIFT + minus"), resize(0, -0.1))
bind(key("SHIFT + equal"), resize(0, 0.1))

bind(key("V"), hl.dsp.window.float({ action = "toggle" }), title("Move Window Between Floating and Tiling"))
bind(key("SHIFT + V"), switch_focus_floating_tiling, title("Switch Focus Between Floating and Tiling"))

-- toggle-column-tabbed-display → Fenstergruppe mit Tabs
bind(key("W"), hl.dsp.group.toggle())


-- Wie Spectacle unter KDE: Bereich wählen → zeichnen → Enter kopiert
bind(key("SHIFT + S"), hl.dsp.exec_cmd("screenshot-edit"))
-- Ohne Zeichnen: Bereich → Clipboard + Datei (Niri: eingebauter Screenshot)
bind("Print", hl.dsp.exec_cmd("screenshot"), title("Take a Screenshot"))

-- Bildschirmteilen (set-dynamic-cast-window/-monitor, clear-dynamic-cast-target,
-- Mod+Ctrl+Shift+F/M/C): gibt es in Hyprland nicht – beim Teilen fragt
-- Hyprland, welches Fenster bzw. welcher Monitor gesendet wird.

-- Wie in Niri eingebaut: Mod + ziehen verschiebt, Mod + Rechtsklick ändert die Größe
hl.bind(key("mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Touchpad: drei Finger hoch/runter wechseln die Arbeitsfläche (wie in Niri)
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
hl.config({ gestures = { workspace_swipe_create_new = true } })


-- ── Übersicht (toggle-overview) ─────────────────────────────
-- Niri hat eine eingebaute Übersicht, Hyprland braucht das Plugin
-- hyprtasking (hyprland.nix). Rechtsklick wechselt die Arbeitsfläche.
hl.plugin.load("/etc/hyprland/plugins/libhyprtasking.so")

-- Die Optionen gibt es erst, nachdem Hyprland das Plugin geladen und die
-- Config neu eingelesen hat
if hl.plugin.hyprtasking then
    hl.config({
        plugin = {
            hyprtasking = {
                layout = "grid",
                gap_size = 16,
                border_size = 2,
                bg_color = 0xff000000 + tonumber(c.surface:sub(2, 7), 16),
                gestures = { enabled = false },
                grid = { rows = 3, cols = 3, gaps_use_aspect_ratio = true },
            },
        },
    })
end


-- ── debug ───────────────────────────────────────────────────

-- RTX 4060 (render-drm-device): AQ_DRM_DEVICES in nvidia.nix

hl.config({
    cursor = {
        -- skip-cursor-only-updates-during-vrr: mit VRR nicht nur für
        -- Mausbewegungen neu zeichnen – sonst schieben sich Extra-Bilder
        -- zwischen die des Spiels und die Bildabstände schwanken
        no_break_fs_vrr = 1,
    },
    render = {
        -- Spiele im Vollbild direkt an den Monitor (Direct Scanout) wie Niri
        direct_scanout = 2,
    },
    misc = {
        -- keine Hyprland-Logos/Standardbilder, Hintergrund macht awww
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        -- abgeschaltete Bildschirme (hypridle) wachen bei Maus/Taste auf,
        -- wie unter Niri
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})
