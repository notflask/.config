-- Solarized Osaka, passend zu Ghostty: Hell/Dunkel folgt 'background'.
-- Neovim fragt das Terminal nach seinem Hintergrund und setzt 'background'
-- (auch später, wenn das System per theme.sh umschaltet); das Farbschema
-- übernimmt die Variante selbst.
return {
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
      colorscheme = "solarized-osaka",
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
