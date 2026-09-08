-- Regression checks for lazy template parsing and signature-cache invalidation.
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(vim.env.NCL_LUASNIP_PATH or vim.fn.stdpath("data") .. "/lazy/LuaSnip")
vim.opt.runtimepath:prepend(root)
vim.bo.filetype = "ncl"
require("tree_sitter_ncl").setup { indent = false, folds = false }
local ls = require("luasnip")
local catalog = vim.json.decode(table.concat(vim.fn.readfile(root .. "/data/ncl-snippets.json"), "\n")).entries
local snippets = ls.get_snippets("ncl")
assert(#snippets == #catalog, "All catalog candidates are immediately registered")
for _, snippet in ipairs(snippets) do
  assert(rawget(snippet, "_snippet") == nil, "Catalog must not eagerly instantiate: " .. snippet.trigger)
end
-- Compare every lazy template with the former eager parser, including multiline
-- templates, choices, repeated placeholders and escapes. No NCL code is executed.
for i, entry in ipairs(catalog) do
  local eager = ls.parser.parse_snippet(entry.trigger, entry.body)
  assert(vim.deep_equal(snippets[i]:get_static_text(), eager:get_static_text()), "Template changed: " .. entry.trigger)
end
local bridge = require("tree_sitter_ncl.snippets")
local registrations = 0
local add_snippets = ls.add_snippets
ls.add_snippets = function(...)
  registrations = registrations + 1
  return add_snippets(...)
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"function report(x)", "begin", "return(x)", "end"})
assert(bridge.refresh_buffer() == 1)
assert(registrations == 1)
for _ = 1, 20 do assert(bridge.refresh_buffer() == 1) end
assert(registrations == 1, "Unchanged buffers must not invalidate completion caches")
vim.api.nvim_buf_set_lines(0, 2, 3, false, {"return(x + 1)"})
bridge.refresh_buffer()
assert(registrations == 1, "Body-only edits must not rebuild identical call snippets")
vim.api.nvim_buf_set_lines(0, 0, 1, false, {"function report(x, y)"})
bridge.refresh_buffer()
assert(registrations == 2, "Parameter edits must refresh call snippets")
local first_buffer = vim.api.nvim_get_current_buf()
vim.cmd("enew")
vim.bo.filetype = "ncl"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"function report(x, y)", "begin", "return(x)", "end"})
bridge.refresh_buffer()
assert(registrations == 3, "Matching signatures in a different buffer need new buffer conditions")
vim.api.nvim_set_current_buf(first_buffer)
bridge.refresh_buffer()
assert(registrations == 4, "Switching back must restore the original buffer's snippets")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"x = 1"})
assert(bridge.refresh_buffer() == 0)
assert(registrations == 5, "Removed definitions must invalidate cached call snippets")
ls.add_snippets = add_snippets
print(string.format("Snippet loading: %d lazy templates match eager output; refresh invalidation checks passed", #catalog))
vim.cmd("qa!")
