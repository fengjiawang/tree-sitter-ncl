local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local defaults = { highlight = true, folds = true, indent = true, snippets = true }

function M.setup(opts)
  opts = vim.tbl_extend("force", defaults, opts or {})
  vim.treesitter.language.add("ncl", { path = root .. "/ncl.so" })
  vim.treesitter.language.register("ncl", "ncl")
  vim.filetype.add { extension = { ncl = "ncl" } }
  for _, kind in ipairs { "highlights", "folds", "tags", "indents" } do
    vim.treesitter.query.set("ncl", kind, table.concat(vim.fn.readfile(root .. "/queries/" .. kind .. ".scm"), "\n"))
  end
  vim.api.nvim_set_hl(0, "@function.custom.ncl", { default = true, link = "Special" })

  local snippets_loaded = false
  local function attach()
    if vim.bo.filetype ~= "ncl" then return end
    if opts.highlight then vim.treesitter.start(0, "ncl") end
    vim.bo.commentstring = "; %s"
    if opts.indent then
      local ok, treesitter = pcall(require, "nvim-treesitter")
      if ok and treesitter.indentexpr then
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        vim.bo.indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e,=end,=else,=elseif,=begin"
      end
    end
    if opts.folds then
      vim.wo.foldmethod = "expr"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end
    -- Migration support: remove only the matches tracked by the former NCL config.
    for _, id in ipairs(vim.w.ncl_syntax_matches or {}) do pcall(vim.fn.matchdelete, id) end
    vim.w.ncl_syntax_matches = nil
    if opts.snippets and not snippets_loaded then
      require("tree_sitter_ncl.snippets").setup(type(opts.snippets) == "table" and opts.snippets or {})
      snippets_loaded = true
    end
  end
  local group = vim.api.nvim_create_augroup("TreeSitterNcl", { clear = true })
  -- Clear the original example's hooks when upgrading an existing session.
  pcall(vim.api.nvim_del_augroup_by_name, "TreeSitterNclPrototype")
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function() vim.schedule(attach) end,
  })
  attach()
end

return M
