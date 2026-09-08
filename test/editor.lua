-- Tests optional editor integrations against installed plugin checkouts, without
-- loading init.lua, the user's ncl.lua, or the original snippets directory.
local root = vim.fn.getcwd()
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.runtimepath:prepend(vim.env.NCL_LUASNIP_PATH or plugins .. "LuaSnip")
vim.opt.runtimepath:prepend(vim.env.NCL_TREESITTER_PATH or plugins .. "nvim-treesitter")
vim.opt.runtimepath:prepend(root)
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
vim.cmd("enew")
vim.bo.filetype = "ncl"
vim.bo.shiftwidth = 2
vim.bo.expandtab = true
dofile(root .. "/examples/neovim.lua")
check(vim.bo.indentexpr:find("nvim%-treesitter") ~= nil, "Tree-sitter indentexpr configured")
local function indent_case(name, lines, expected)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  local parser = vim.treesitter.get_parser(0, "ncl")
  parser:parse()
  for line, width in ipairs(expected) do
    local actual = require("nvim-treesitter.indent").get_indent(line)
    check(actual == width, string.format("%s line %d: expected %d, got %d", name, line, width, actual))
  end
end
indent_case("nested blocks and branches", {
  "begin", "do i = 0, 3", "if True then", "print(i)", "elseif False then",
  "print(0)", "else", "print(1)", "end if", "end do", "end",
}, {0, 2, 4, 6, 4, 6, 4, 6, 4, 2, 0})
indent_case("function locals", {
  "function f(x:numeric)", "local y", "begin", "y = x", "return(y)", "end",
}, {0, 0, 0, 2, 2, 0})
indent_case("graphics", {
  "begin", 'obj = create "plot" appClass defaultapp', '"wkWidth" : 800', "end create",
  "setvalues obj", '"wkWidth" : 1024', "end setvalues",
  "getvalues obj", '"wkWidth" : width', "end getvalues", "end",
}, {0, 2, 4, 2, 2, 4, 2, 2, 4, 2, 0})
indent_case("continuation", {
  "begin", "x = (/1, \\", "2, \\", "3/)", "end",
}, {0, 2, 4, 4, 0})
indent_case("unfinished block", { "begin", "print(1)", "" }, {0, 2, 2})
indent_case("unfinished conditional", { "if True then", "print(1)", "" }, {0, 2, 2})
indent_case("end statements do not indent following lines", {
  "do i = 0, 1", "print(i)", "end do", "", "if True then", "print(1)", "end if", "",
  "begin", "print(1)", "end", "",
}, {0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0})
indent_case("comments and blank lines", {
  "begin", "; comment", "", 'print("; string")', "end",
}, {0, 2, 2, 2, 0})
vim.bo.shiftwidth = 4
indent_case("four space settings", {"begin", "print(1)", "end"}, {0, 4, 0})
vim.bo.shiftwidth = 2
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"begin", "if True then", "print(1)", "else", "print(0)", "end if", "end"})
vim.cmd("normal! gg=G")
local formatted = {"begin", "  if True then", "    print(1)", "  else", "    print(0)", "  end if", "end"}
check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), formatted), "Actual gg=G formats nested branches")
vim.cmd("normal! gg=G")
check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), formatted), "Reindent is idempotent")

local ls = require("luasnip")
local bridge = require("tree_sitter_ncl.snippets")
local count = bridge.setup()
check(count == 3470, "Complete project catalog registered")
bridge.setup()
local snippets = ls.get_snippets("ncl")
local found = {}
for _, snippet in ipairs(snippets) do
  if not snippet.invalidated then
    found[snippet.trigger] = found[snippet.trigger] or {}
    table.insert(found[snippet.trigger], snippet)
  end
end
check(#found.abs == 1, "Repeated setup replaces its own catalog")
check(found.initplot ~= nil and found["@cnFillOn"] ~= nil, "Custom and resource templates migrated")
local function buffer(lines, row, col)
  if ls.session.current_nodes[vim.api.nvim_get_current_buf()] then ls.unlink_current() end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, {row or #lines, col or #lines[#lines]})
  vim.treesitter.get_parser(0, "ncl"):parse()
end
buffer({"function abs(value:numeric)", "begin", "return(value)", "end", "abs"})
check(bridge.refresh_buffer() == 0, "Built-in catalog trigger is not generated from buffer")
local abs_count = 0
for _, snippet in ipairs(ls.get_snippets("ncl")) do
  if not snippet.invalidated and snippet.trigger == "abs" then abs_count = abs_count + 1 end
end
check(abs_count == 1, "Built-in catalog trigger appears only once")
buffer({"abs"})
check(bridge.context() == "code", "Code context")
check(found.abs[1].show_condition(), "Function template allowed in code")
buffer({'; abs'})
check(bridge.context() == "comment" and not found.abs[1].show_condition(), "No function snippets in comments")
check(found.abs[1]:matches("; abs") == nil, "Expansion itself is blocked in comments")
buffer({'x = "abs"'}, 1, 8)
check(bridge.context() == "string" and not found.abs[1].show_condition(), "No function snippets in strings")
check(found.amwg256[1].show_condition(), "Color template allowed in strings")
buffer({'x = "amwg256'}, 1, 11)
check(bridge.context() == "string", "Incomplete strings retain context while typing")
buffer({"abs"})
check(not found.amwg256[1].show_condition(), "Color template hidden in code")

-- Expand through LuaSnip's trigger matcher, then jump between real placeholders.
vim.o.virtualedit = "onemore"
buffer({"actvpr_mnmx_fao56"})
check(ls.expandable(), "Catalog trigger matched")
ls.expand()
check(vim.api.nvim_get_current_line() == "actvpr_mnmx_fao56(tmin, tmax, rhmin, rhmax, iounit)", "Real signature expanded")
check(ls.jumpable(1), "Snippet has navigable argument placeholders")
ls.jump(1)
check(ls.session.current_nodes[vim.api.nvim_get_current_buf()].pos == 2, "Jump reaches second parameter")
buffer({"do-while"})
check(ls.expandable(), "Migrated while trigger matched")
ls.expand()
check(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "do while (conditions)", "Migrated while template has corrected NCL syntax")

buffer({"function my_anomaly(x:numeric, baseline:numeric)", "begin", "return(x-baseline)", "end", "my_anomaly"})
check(bridge.refresh_buffer() == 1, "Function discovered from syntax tree")
check(ls.expandable(), "Generated function trigger matched")
ls.expand()
check(vim.api.nvim_get_current_line() == "my_anomaly(x, baseline)", "AST parameter names used in placeholders")
check(ls.jumpable(1), "AST-generated arguments are editable placeholders")
buffer({"x = 1"})
check(bridge.refresh_buffer() == 0, "Removed function disappears on refresh")
buffer({"procedure my_report(value:numeric)", "begin", "print(value)", "end", "my_report"})
check(bridge.refresh_buffer() == 1, "Procedure discovered from syntax tree")
check(ls.expandable(), "Generated procedure trigger matched")
ls.expand()
check(vim.api.nvim_get_current_line() == "my_report(value)", "Procedure parameter used in placeholder")
check(bridge.setup({catalog = false}) == 0, "AST-only mode loads no template catalog")
local has_abs, has_report = false, false
for _, snippet in ipairs(ls.get_snippets("ncl")) do
  if not snippet.invalidated then
    has_abs = has_abs or snippet.trigger == "abs"
    has_report = has_report or snippet.trigger == "my_report"
  end
end
check(not has_abs and has_report, "AST-only mode retains only current-buffer generated snippets")

print(string.format("Editor integrations: %d checks passed; %d project snippet triggers", checks, count))
vim.cmd("qa!")
