local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local ls
local cached_context = {}
local catalog_triggers = {}

-- Tree-sitter supplies context, while the catalog supplies argument names,
-- descriptions and templates that a grammar cannot infer for library functions.
local function context()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "ncl" then return "other" end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local key = table.concat({ bufnr, tick, cursor[1], cursor[2] }, ":")
  if cached_context.key == key then return cached_context.value end
  local function remember(value)
    cached_context = { key = key, value = value }
    return value
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "ncl")
  if not ok then return "other" end
  local tree = parser:parse()[1]
  if not tree then return "other" end
  local row, col = cursor[1] - 1, math.max(cursor[2] - 1, 0)
  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node do
    local kind = node:type()
    if kind == "comment" or kind == "block_comment" then return remember("comment") end
    if kind == "string" or kind == "string_content" or kind == "escape_sequence" then return remember("string") end
    node = node:parent()
  end
  return remember("code")
end

local function in_code() return context() == "code" end
local function in_string() return context() == "string" end
M.context = context
function M.is_catalog_trigger(trigger) return catalog_triggers[trigger] == true end

local function configure_blink_buffer_filter()
  local ok, config = pcall(require, "blink.cmp.config")
  if not ok or not config.sources.providers.buffer then return end
  local provider = config.sources.providers.buffer
  if provider.tree_sitter_ncl_filter then return end
  local previous = provider.transform_items
  provider.transform_items = function(context, items)
    if previous then items = previous(context, items) end
    if vim.bo.filetype ~= "ncl" then return items end
    return vim.tbl_filter(function(item)
      return not M.is_catalog_trigger(item.label)
    end, items)
  end
  provider.tree_sitter_ncl_filter = true
end

function M.refresh_buffer()
  if not ls or vim.bo.filetype ~= "ncl" then return end
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "ncl")
  if not ok then return end
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse("ncl", [[
    [(function_definition) (procedure_definition)] @definition
  ]])
  local snippets, seen = {}, {}
  for _, definition in query:iter_captures(tree:root(), bufnr) do
    local name_node = definition:field("name")[1]
    local parameters = definition:field("parameters")[1]
    if name_node and parameters and not definition:has_error() then
      local name = vim.treesitter.get_node_text(name_node, bufnr)
      if not seen[name] and not catalog_triggers[name] then
        seen[name] = true
        local args = {}
        for parameter in parameters:iter_children() do
          if parameter:type() == "parameter" then
            local param_name = vim.treesitter.get_node_text(parameter:field("name")[1], bufnr)
            args[#args + 1] = string.format("${%d:%s}", #args + 1, param_name)
          end
        end
        snippets[#snippets + 1] = ls.parser.parse_snippet({
          trig = name, name = name, dscr = "From this buffer's NCL syntax tree",
          priority = 1200,
          condition = function() return vim.api.nvim_get_current_buf() == bufnr and in_code() end,
          show_condition = function() return vim.api.nvim_get_current_buf() == bufnr and in_code() end,
        }, name .. "(" .. table.concat(args, ", ") .. ")$0")
      end
    end
  end
  -- Replace the previous buffer's generated snippets; don't accumulate them.
  ls.add_snippets("ncl", snippets, { key = "tree-sitter-ncl-buffer" })
  return #snippets
end

function M.setup(opts)
  opts = opts or {}
  ls = require("luasnip")
  configure_blink_buffer_filter()
  catalog_triggers = {}
  local entries = {}
  if opts.catalog ~= false then
    entries = vim.json.decode(table.concat(vim.fn.readfile(root .. "/data/ncl-snippets.json"), "\n")).entries
  end
  local snippets = {}
  for _, entry in ipairs(entries) do
    catalog_triggers[entry.trigger] = true
    local is_string = entry.category == "color_table" or entry.category == "font"
    local condition = is_string and in_string or in_code
    snippets[#snippets + 1] = ls.parser.parse_snippet({
      trig = entry.trigger, name = entry.name, dscr = entry.description,
      wordTrig = entry.trigger:sub(1, 1) ~= "@",
      condition = condition, show_condition = condition,
    }, entry.body)
  end
  ls.add_snippets("ncl", snippets, { key = "tree-sitter-ncl-catalog" })
  local group = vim.api.nvim_create_augroup("TreeSitterNclSnippets", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "InsertEnter", "InsertLeave" }, {
    group = group,
    callback = M.refresh_buffer,
  })
  M.refresh_buffer()
  return #snippets
end

return M
