-- ============================================================
--  Hyprland in den Stilen islands und frame (`style islands|frame`):
--  deckend und rund, weiche Schatten, kein Blur. Animationen bleiben
--  (hyprland.lua). Geladen am Ende von hyprland.lua, überschreibt nur
--  das Aussehen. Leiste: quickshell/islands.
-- ============================================================

return function(style, c)
    local frame = style == "frame"
    hl.config({
        general = {
            -- islands: luftig wie die Inseln der Leiste (12 zwischen den
            -- Fenstern, 14 zum Rand). frame: der Rahmen ist schon der Rand,
            -- Fenster sitzen mit 6 px darin (Radius 20 − 6 = 14, konzentrisch)
            gaps_in = frame and 4 or 6,
            gaps_out = frame and 6 or 14,
            border_size = 2,
            col = {
                active_border = c.primary,
                inactive_border = "#00000000",
            },
        },
        decoration = {
            rounding = frame and 14 or 18,
            rounding_power = 2,
            -- weicher Schatten nach unten statt Glasrand
            shadow = {
                enabled = true,
                range = 24,
                render_power = 3,
                offset = { 0, 4 },
                color = "#00000038",
                color_inactive = "#00000020",
            },
            blur = { enabled = false },
        },
    })
end
