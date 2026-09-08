-- Run :luafile /path/to/tree-sitter-ncl/examples/neovim.lua
-- after `npm run build`. Uses Neovim's native Tree-sitter API (0.11+).
-- The repository and your existing ncl.lua can remain in their current paths.
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.treesitter.language.add("ncl", { path = root .. "/ncl.so" })
vim.treesitter.language.register("ncl", "ncl")
vim.filetype.add { extension = { ncl = "ncl" } }
for _, kind in ipairs { "highlights", "folds", "tags", "indents" } do
  local text = table.concat(vim.fn.readfile(root .. "/queries/" .. kind .. ".scm"), "\n")
  vim.treesitter.query.set("ncl", kind, text)
end
vim.api.nvim_set_hl(0, "@function.custom.ncl", { default = true, link = "Special" })

local function attach()
  if vim.bo.filetype ~= "ncl" then return end
  vim.treesitter.start(0, "ncl")
  vim.bo.commentstring = "; %s"
  local has_indent, treesitter = pcall(require, "nvim-treesitter")
  if has_indent and treesitter.indentexpr then
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    vim.bo.indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e,=end,=else,=elseif,=begin"
  end
  vim.wo.foldmethod = "expr"
  vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  -- The supplied ncl.lua uses window-local matchadd(), which overrides syntax
  -- highlighting even inside strings. Remove only matches tracked by it.
  for _, id in ipairs(vim.w.ncl_syntax_matches or {}) do
    pcall(vim.fn.matchdelete, id)
  end
  vim.w.ncl_syntax_matches = nil
end
local group = vim.api.nvim_create_augroup("TreeSitterNclPrototype", { clear = true })
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
  group = group,
  callback = function()
    -- Run after the existing AstroNvim callbacks have set buffer/window options.
    vim.schedule(attach)
  end,
})
attach()
