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
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "vague",
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
