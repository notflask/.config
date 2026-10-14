-- Farbschema: Systemfarben `matugen` (colors/matugen.lua, aus dem Wallpaper
-- erzeugt von theme.sh – wie Ghostty), in beiden Stilen. Solarized Osaka nur
-- als Rückfall, solange matugen die Datei noch nicht erzeugt hat. Hell/Dunkel
-- folgt 'background': Neovim fragt das Terminal nach seinem Hintergrund und
-- setzt 'background' (auch später, wenn das System per theme.sh umschaltet).
local colors_dir = vim.fn.stdpath("config") .. "/colors"
local matugen = vim.uv.fs_stat(colors_dir .. "/matugen.lua") ~= nil

-- Systemfarben live übernehmen: schreibt matugen (theme.sh) die Datei neu,
-- lädt jede laufende Instanz das Schema neu (kurz gesammelt, da matugen in
-- mehreren Schritten schreibt). Auch in tmux und ohne Server-Socket.
if matugen then
  local watcher, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  watcher:start(colors_dir, {}, function(_, file)
    if file ~= "matugen.lua" then return end
    timer:start(150, 0, vim.schedule_wrap(function()
      if vim.g.colors_name == "matugen" then vim.cmd.colorscheme("matugen") end
    end))
  end)
end

return {
  {
    "craftzdog/solarized-osaka.nvim",
    opts = {
      transparent = true,
    },
    lazy = false,
    priority = 1000,
  },

  -- Grundlage für colors/matugen.lua
  { "nvim-mini/mini.base16", version = false, lazy = false, priority = 1000 },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = matugen and "matugen" or "solarized-osaka",
    },
  },

  {
    "snacks.nvim",
    opts = {
      indent = { enabled = false },
    },
  },

  { "akinsho/bufferline.nvim", version = "*", dependencies = "nvim-tree/nvim-web-devicons", enabled = false },
  { "nvim-lualine/lualine.nvim", enabled = false },
  { "folke/noice.nvim", enabled = false },
}
