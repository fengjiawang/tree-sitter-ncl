-- Native integration tests: no user init.lua, plugins, or NCAR runtime needed.
local root = vim.fn.getcwd()
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
vim.treesitter.language.add("ncl", { path = root .. "/ncl.so" })
local function parse(text)
  local parser = vim.treesitter.get_string_parser(text, "ncl")
  local node = parser:parse()[1]:root()
  check(not node:has_error(), "Parse failed: " .. text .. "\n" .. node:sexpr())
  return node
end
local function read(path)
  return table.concat(vim.fn.readfile(root .. "/" .. path), "\n")
end
local queries = {}
for _, kind in ipairs { "highlights", "folds", "tags", "indents" } do
  queries[kind] = vim.treesitter.query.parse("ncl", read("queries/" .. kind .. ".scm"))
  check(queries[kind] ~= nil, "Query compilation: " .. kind)
end
local function captures(query, tree, text)
  local result = {}
  for id, node in query:iter_captures(tree, text, 0, -1) do
    local name = query.captures[id]
    result[name] = result[name] or {}
    result[name][vim.treesitter.get_node_text(node, text)] = true
  end
  return result
end
for _, file in ipairs { "examples/weather.ncl", "examples/language.ncl" } do
  local text = read(file)
  local tree = parse(text)
  local h = captures(queries.highlights, tree, text)
  check(h["function.builtin"] ~= nil, "Builtin function captures in " .. file)
  check(h.property ~= nil, "Resource captures in " .. file)
  check(captures(queries.folds, tree, text).fold ~= nil, "Fold captures in " .. file)
  check(captures(queries.tags, tree, text)["definition.function"] ~= nil, "Definition tags in " .. file)
end
local text = 'print("gsn_panel; draw_China_shapefile @cnFillOn")\n'
  .. '; print(1)\nres@cnFillOn = True\n'
  .. 'draw_China_shapefile(wks, plot, res)\nunknown_proc(x)\nx = data(0)\n'
local h = captures(queries.highlights, parse(text), text)
check(h["function.builtin"].print, "print is a builtin")
check(not h["function.builtin"].gsn_panel, "String content must not become a builtin capture")
check(h["function.custom"].draw_China_shapefile, "Custom function from ncl.lua")
check(h["function.call"].unknown_proc, "Unknown procedures still highlight in statement position")
check(not (h["function.call"] or {}).data, "Array indexing must not be classified as a known call")
check(h.property.cnFillOn, "Resource attribute capture")
check(h.comment['; print(1)'], "Comment must remain one comment")

-- Explicit field and grouping checks independent of generated corpus snapshots.
local expr = parse("x = -3^2^4"):named_child(0):field("right")[1]
check(expr:type() == "binary_expression", "Power expression node")
local left = expr:field("left")[1]
check(left:type() == "binary_expression", "Power is left associative")
check(left:field("left")[1]:type() == "unary_expression", "Unary minus binds before power")
local slice = parse("x = a(1:5:2)"):named_child(0):field("right")[1]:field("arguments")[1]:named_child(0)
check(slice:field("start")[1]:type() == "integer", "Slice start field")
check(slice:field("end")[1]:type() == "integer", "Slice end field")
check(slice:field("step")[1]:type() == "integer", "Slice step field")
parse("begin\r\nx = 1.\r\ny = 1.eq.2\r\nend")
parse("x = 1.\n; EOF comment")
parse("x = 1..eq.2.\ny = 2e3.eq.4\nz = 1.and.True")
local recovery = vim.treesitter.get_string_parser("x =\ny = 2\n", "ncl"):parse()[1]:root()
check(recovery:has_error(), "Malformed assignment must report an error")
check(recovery:sexpr():find("assignment_statement", 1, true) ~= nil, "Parser recovers a following assignment")

-- Check actual buffer attachment and parser reuse across edits.
vim.cmd("enew")
vim.bo.filetype = "ncl"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1.eq.2", "res@cnFillOn = True" })
vim.w.ncl_syntax_matches = { vim.fn.matchadd("Error", "cnFillOn") }
dofile(root .. "/examples/neovim.lua")
check(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil, "Native highlighter attached")
check(vim.w.ncl_syntax_matches == nil, "Legacy regex matches cleared")
check(vim.wo.foldmethod == "expr", "Tree-sitter folding enabled")
local parser = vim.treesitter.get_parser(0, "ncl")
check(not parser:parse()[1]:root():has_error(), "Buffer parses initially")
for _, line in ipairs { "x = 1..eq.2", "x = 1.e3.eq.2", "x = 1.eq.2" } do
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { line })
  local tree = parser:parse()[1]:root()
  local fresh = parse(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n")
  check(tree:sexpr() == fresh:sexpr(), "Incremental result equals fresh parse: " .. line)
end
print(string.format("Neovim integration: %d checks passed", checks))
vim.cmd("qa!")
