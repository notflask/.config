-- Typst für Mathe-Notizen: tinymist (LSP) und typstyle (Formatter) kommen aus
-- Portage, nicht von Mason. Den Rest (Treesitter, Browser-Vorschau <leader>cp,
-- Formatieren) bringt das LazyVim-Extra lang.typst (lazyvim.json).
--
-- Ablauf: Notiz.typ speichern → tinymist schreibt Notiz.pdf daneben.
-- <leader>co öffnet die PDF in mizu (einmal pro Notiz).
local function open_pdf()
  local pdf = vim.fn.expand("%:p:r") .. ".pdf"
  if vim.fn.filereadable(pdf) == 0 then
    vim.notify("Noch keine PDF – erst speichern (tinymist exportiert beim Speichern)", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart({ "mizu", pdf }, { detach = true })
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tinymist = {
          mason = false,
          settings = {
            -- PDF beim Speichern neben die .typ-Datei legen
            exportPdf = "onSave",
            outputPath = "$root/$dir/$name",
            formatterMode = "typstyle",
            -- Mathe-Syntax in der Vorschau/Hover sauber hervorheben
            semanticTokens = "enable",
          },
          keys = {
            { "<leader>co", open_pdf, desc = "Open PDF in mizu" },
          },
        },
      },
    },
  },
}
