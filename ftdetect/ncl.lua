-- Neovim otherwise detects .ncl as Nickel. Lazy.nvim loads ftdetect before
-- resolving ft = "ncl", so the plugin also works on the first opened file.
vim.filetype.add { extension = { ncl = "ncl" } }
