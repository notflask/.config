-- Erzeugt von matugen (templates/nvim-colors.lua) – hier nichts ändern.
-- Farbschema `matugen` für Neovim im minimalen Stil (plugins/ui.lua): Flächen,
-- Schrift, Auswahl und Funktionen aus dem Wallpaper, die übrigen
-- Syntaxfarben wie die Terminalfarben in Ghostty (templates/ghostty-theme).
-- theme.sh lädt es in laufenden Neovims neu.
local c = {
  surface = "{{colors.surface.default.hex}}",
  container = "{{colors.surface_container.default.hex}}",
  container_high = "{{colors.surface_container_highest.default.hex}}",
  outline = "{{colors.outline.default.hex}}",
  outline_variant = "{{colors.outline_variant.default.hex}}",
  on_surface = "{{colors.on_surface.default.hex}}",
  on_surface_variant = "{{colors.on_surface_variant.default.hex}}",
  primary = "{{colors.primary.default.hex}}",
  primary_container = "{{colors.primary_container.default.hex}}",
  on_primary_container = "{{colors.on_primary_container.default.hex}}",
  tertiary = "{{colors.tertiary.default.hex}}",
  error = "{{colors.error.default.hex}}",
<* if {{ is_dark_mode }} *>
  red = "#d8647e", green = "#7fa563", yellow = "#f3be7c",
  magenta = "#bb9dbd", cyan = "#aeaed1",
<* else *>
  red = "#db302d", green = "#849900", yellow = "#b28500",
  magenta = "#d23681", cyan = "#29a298",
<* endif *>
}

vim.o.background = "<* if {{ is_dark_mode }} *>dark<* else *>light<* endif *>"
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
