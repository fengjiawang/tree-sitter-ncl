local root = vim.fn.getcwd()
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.runtimepath:prepend(vim.env.NCL_BLINK_PATH or plugins .. "blink.cmp")
vim.opt.runtimepath:prepend(vim.env.NCL_LUASNIP_PATH or plugins .. "LuaSnip")
vim.opt.runtimepath:prepend(root)
require("blink.cmp").setup { fuzzy = { implementation = "lua" } }
local config = require("blink.cmp.config")
local original_active, original_jump = config.snippets.active, config.snippets.jump
local calls = 0
config.snippets.active = function() calls = calls + 1; return "original" end
config.snippets.jump = function() calls = calls + 1; return "original" end
vim.bo.filetype = "ncl"
require("tree_sitter_ncl").setup { indent = false }
local sources = require("blink.cmp.sources.lib")
local ids = sources.get_enabled_provider_ids("default")
assert(vim.tbl_contains(ids, "ncl_snippets") and not vim.tbl_contains(ids, "snippets"), "NCL must bypass the native disk snippet loader")
local source = require("blink.cmp.sources.snippets.luasnip").new({})
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"abs"})
vim.o.virtualedit = "onemore"
vim.api.nvim_win_set_cursor(0, {1, 3})
local found
source:get_completions({line="abs", cursor={1, 4}}, function(result)
  for _, item in ipairs(result.items) do if item.label == "abs" then found = item end end
end)
assert(found, "Project snippets appear in blink candidates")
source:resolve(found, function(item) assert(item.detail:find("value"), "Candidate has argument documentation") end)
local ls = require("luasnip")
ls.lsp_expand("f(${1:x}, ${2:y})")
assert(config.snippets.active({direction=1}), "NCL jump handler sees LuaSnip placeholders")
config.snippets.jump(1)
assert(ls.session.current_nodes[vim.api.nvim_get_current_buf()].pos == 2, "Blink jumps to the second LuaSnip argument")
local active_handler = config.snippets.active
require("tree_sitter_ncl.blink").setup()
assert(config.snippets.active == active_handler, "Repeated setup does not wrap handlers twice")
vim.bo.filetype = "python"
ids = sources.get_enabled_provider_ids("default")
assert(vim.tbl_contains(ids,"snippets") and not vim.tbl_contains(ids,"ncl_snippets"), "Other filetypes retain their sources")
assert(config.snippets.active({}) == "original" and config.snippets.jump(1) == "original" and calls == 2, "Other filetypes retain their snippet handlers")
local items = config.sources.providers.buffer.transform_items({}, {{label="abs"}})
assert(#items == 1, "Other filetypes retain buffer candidates")
config.snippets.active, config.snippets.jump = original_active, original_jump
print("blink.cmp integration: 9 checks passed")
vim.cmd("qa!")
