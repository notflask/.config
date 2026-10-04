-- Farbschema passend zu Ghostty: dunkel Vague, hell Solarized Osaka (Light).
-- Neovim fragt das Terminal nach seinem Hintergrund und setzt 'background'
-- (auch später, wenn das System per theme.sh umschaltet).
local function colorscheme()
  local wanted = vim.o.background == "light" and "solarized-osaka" or "vague"
  -- :colorscheme setzt selbst 'background' – nur wechseln, wenn nötig
  if vim.g.colors_name ~= wanted then
    vim.cmd.colorscheme(wanted)
  end
end

vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    vim.schedule(colorscheme)
  end,
})

return {
  {
    "vague-theme/vague.nvim",
    opts = {
      transparent = true,
    },
    lazy = false,
    priority = 1000,
  },

  {
    "craftzdog/solarized-osaka.nvim",
    opts = {
      transparent = true,
    },
    lazy = false,
    priority = 1000,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = colorscheme,
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
