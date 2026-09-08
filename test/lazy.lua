-- Exercise the documented lazy.nvim spec, including cold .ncl detection.
local root = vim.fn.getcwd()
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.runtimepath:prepend(vim.env.NCL_LAZY_PATH or plugins .. "lazy.nvim")
vim.go.loadplugins = true
require("lazy").setup({
  {
    "fengjiawang/tree-sitter-ncl", dir = root,
    ft = "ncl", build = "make",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter", dir = vim.env.NCL_TREESITTER_PATH or plugins .. "nvim-treesitter" },
      { "L3MON4D3/LuaSnip", dir = vim.env.NCL_LUASNIP_PATH or plugins .. "LuaSnip" },
    },
    opts = {},
  },
}, {
  install = { missing = false }, checker = { enabled = false },
  change_detection = { enabled = false }, lockfile = root .. "/.cache/test-lazy-lock.json",
})
assert(not require("lazy.core.config").plugins["tree-sitter-ncl"]._.loaded, "Must be lazy before opening NCL")
vim.cmd.edit(root .. "/examples/weather.ncl")
vim.wait(1000, function() return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil end)
assert(vim.bo.filetype == "ncl", "Cold file detection must override Nickel")
assert(require("lazy.core.config").plugins["tree-sitter-ncl"]._.loaded, "FileType must load the plugin")
assert(require("lazy.core.loader").get_main(require("lazy.core.config").plugins["tree-sitter-ncl"]) == "tree_sitter_ncl", "opts must resolve setup automatically")
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "Highlight enabled")
assert(vim.bo.indentexpr:find("nvim%-treesitter"), "Indent enabled")
assert(vim.wo.foldmethod == "expr", "Folds enabled")
local count = 0
for _, s in ipairs(require("luasnip").get_snippets("ncl")) do if not s.invalidated then count = count + 1 end end
assert(count >= 3470, "Catalog enabled by default")
-- A new filetype must not inherit NCL options from the deferred callback.
vim.cmd.enew()
vim.bo.filetype = "text"
vim.bo.indentexpr = ""
vim.wait(20)
assert(vim.bo.indentexpr == "", "Other filetypes keep their indentation")
print("lazy.nvim installation: 9 checks passed")
vim.cmd("qa!")
