-- Erzeugt von matugen (templates/nvim-colors.lua) – hier nichts ändern.
-- Farbschema `matugen` für Neovim im minimalen Stil (plugins/ui.lua): Flächen,
-- Schrift, Auswahl und Funktionen aus dem Wallpaper, die übrigen
-- Syntaxfarben wie die Terminalfarben in Ghostty (templates/ghostty-theme).
-- theme.sh lädt es in laufenden Neovims neu.
local c = {
  surface = "#131315",
  container = "#201f21",
  container_high = "#353436",
  outline = "#929092",
  outline_variant = "#474648",
  on_surface = "#e5e1e3",
  on_surface_variant = "#c9c6c7",
  primary = "#c6c5d6",
  primary_container = "#454654",
  on_primary_container = "#e2e1f3",
  tertiary = "#c4c4dd",
  error = "#ffb4ab",
red = "#d8647e", green = "#7fa563", yellow = "#f3be7c",
  magenta = "#bb9dbd", cyan = "#aeaed1",

}

vim.o.background = "dark"
require("mini.base16").setup({
  palette = {
    base00 = c.surface,
    base01 = c.container,
    base02 = c.container_high,
    base03 = c.outline,
    base04 = c.on_surface_variant,
    base05 = c.on_surface,
    base06 = c.on_surface,
    base07 = c.on_surface,
    base08 = c.red,
    base09 = c.tertiary,
    base0A = c.yellow,
    base0B = c.green,
    base0C = c.cyan,
    base0D = c.primary,
    base0E = c.magenta,
    base0F = c.error,
  },
})
vim.g.colors_name = "matugen"

local hl = function(name, opts) vim.api.nvim_set_hl(0, name, opts) end
hl("Visual", { bg = c.primary_container, fg = c.on_primary_container })
hl("Cursor", { bg = c.primary, fg = c.surface })
hl("CursorLine", { bg = c.container })
hl("CursorLineNr", { fg = c.primary, bold = true })
hl("LineNr", { fg = c.outline_variant })
hl("NormalFloat", { bg = c.container, fg = c.on_surface })
hl("FloatBorder", { bg = c.container, fg = c.outline })
hl("WinSeparator", { fg = c.outline_variant })
hl("Comment", { fg = c.outline, italic = true })
hl("@comment", { link = "Comment" })
