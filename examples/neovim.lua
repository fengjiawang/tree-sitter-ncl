-- Standalone parser demo; the normal plugin entry point is setup().
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
require("tree_sitter_ncl").setup { snippets = false }
