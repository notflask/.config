-- ============================================================
--  Hyprland unter Void Linux (linux/void, hyprland-session):
--  derselbe minimale Stil wie MangoWC (mango/config.conf) –
--  eckig, 1px-Rahmen, keine Effekte, das Wallpaper ist die Deko.
--  Geladen am Ende von hyprland.lua, überschreibt nur das Aussehen.
-- ============================================================

hl.config({
    general = {
        -- gappih/gappiv 10 (gaps_in gilt pro Fensterseite), gappoh/gappov 12
        gaps_in = 5,
        gaps_out = 12,
        border_size = 1,
    },
    decoration = {
        rounding = 0,
        -- keine Schatten, kein Blur (spart auch GPU fürs Spielen)
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    -- keine Animationen: Fenster und Arbeitsflächen sind sofort da
    animations = { enabled = false },
})
