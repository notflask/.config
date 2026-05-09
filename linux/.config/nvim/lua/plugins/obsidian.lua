return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "personal",
          path = "~/vaults/personal",
        },
      },
    },
  },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.opt.updatetime = 300
      vim.g.mkdp_markdown_css = vim.fn.expand("~/.config/nvim/obsidian-style.css")
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_page_title = "${name}"
      vim.g.mkdp_preview_options = {
        mkit = { breaks = true },
      }
    end,
  },
}
