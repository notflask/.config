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
    "lervag/vimtex",
    lazy = false,
    init = function()
	vim.g.vimtex_view_general_viewer = "sioyek"
    end
  }
}
