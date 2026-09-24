return {
  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_build_directory = function()
        return "build/${variant:buildType}"
      end,
      cmake_compile_commands_options = {
        action = "none",
        target = vim.loop.cwd(),
      },
    }
  },
  {
    -- NixOS: clangd can't find the std headers on its own, it has to ask the nix gcc wrapper
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
            "--query-driver=/run/current-system/sw/bin/*,/etc/profiles/per-user/*/bin/*,/home/*/.nix-profile/bin/*,/nix/store/**/bin/*",
          },
          -- clangd parses `gcc -v` output and only understands English
          cmd_env = { LC_ALL = "C" },
        },
      },
    },
  },
  {
    "lervag/vimtex",
    lazy = false,
    init = function()
	vim.g.vimtex_view_general_viewer = "sioyek"
    end
  }
}
