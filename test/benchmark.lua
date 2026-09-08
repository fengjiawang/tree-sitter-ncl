-- Isolated NCL setup benchmark: compare medians from several fresh processes.
local root = vim.env.NCL_BENCH_ROOT or vim.fn.getcwd()
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.runtimepath:prepend(vim.env.NCL_LUASNIP_PATH or plugins .. "LuaSnip")
vim.opt.runtimepath:prepend(vim.env.NCL_TREESITTER_PATH or plugins .. "nvim-treesitter")
vim.opt.runtimepath:prepend(root)
vim.cmd.edit(root .. "/examples/weather.ncl")
vim.bo.filetype = "ncl"
local stats = {}
local function wrap(object, name, label)
  local original = object[name]
  object[name] = function(...)
    local started = vim.uv.hrtime()
    local result = { original(...) }
    stats[label] = (stats[label] or 0) + (vim.uv.hrtime() - started) / 1e6
    return unpack(result)
  end
end
local ls = require("luasnip")
wrap(ls.parser, "parse_snippet", "parse_templates_ms")
wrap(ls, "add_snippets", "register_ms")
wrap(vim.treesitter.query, "set", "queries_ms")
local module = require("tree_sitter_ncl")
local started = vim.uv.hrtime()
module.setup()
stats.setup_ms = (vim.uv.hrtime() - started) / 1e6
vim.wait(20)
local bridge = require("tree_sitter_ncl.snippets")
started = vim.uv.hrtime()
for _ = 1, 20 do bridge.refresh_buffer() end
stats.refresh_20_ms = (vim.uv.hrtime() - started) / 1e6
local instantiated = 0
for _, snippet in ipairs(ls.get_snippets("ncl")) do
  if rawget(snippet, "_snippet") then instantiated = instantiated + 1 end
end
stats.instantiated_proxies = instantiated
print("NCL_BENCH " .. vim.json.encode(stats))
vim.cmd("qa!")
