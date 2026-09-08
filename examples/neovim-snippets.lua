-- Load after examples/neovim.lua. Keep LuaSnip and your completion/key mappings,
-- but remove the old load_ncl_snippets() call from your NCL config to avoid
-- registering two independent copies of the same templates.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
local has_lazy, lazy = pcall(require, "lazy")
if has_lazy then lazy.load { plugins = { "LuaSnip" } } end
require("tree_sitter_ncl.snippets").setup()
