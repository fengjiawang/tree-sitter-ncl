-- Optional blink.cmp integration, scoped to NCL. Other filetypes keep their
-- existing completion sources and snippet engine.
local M = {}

function M.setup()
  local ok, blink = pcall(require, "blink.cmp")
  if not ok or not blink.add_source_provider then return end
  local config = require("blink.cmp.config")
  if not config.sources or config.sources.providers.ncl_snippets then return end
  blink.add_source_provider("ncl_snippets", {
    name = "NCL", module = "blink.cmp.sources.snippets.luasnip", opts = {},
  })
  local previous_sources = config.sources.per_filetype.ncl
  config.sources.per_filetype.ncl = function()
    local defaults = config.sources.default
    if type(defaults) == "function" then defaults = defaults() end
    local sources = previous_sources
    if type(sources) == "function" then sources = sources() end
    sources = vim.deepcopy(sources or defaults)
    if sources.inherit_defaults then vim.list_extend(sources, defaults) end
    sources = vim.tbl_filter(function(id) return id ~= "snippets" and id ~= "ncl_snippets" end, sources)
    sources[#sources + 1] = "ncl_snippets"
    return sources
  end

  local previous_active, previous_jump = config.snippets.active, config.snippets.jump
  config.snippets.active = function(filter)
    if vim.bo.filetype ~= "ncl" then return previous_active(filter) end
    local ls = require("luasnip")
    return ls.locally_jumpable(filter and filter.direction or 1)
  end
  config.snippets.jump = function(direction)
    if vim.bo.filetype ~= "ncl" then return previous_jump(direction) end
    local ls = require("luasnip")
    if ls.locally_jumpable(direction) then return ls.jump(direction) end
  end
  local provider = config.sources.providers.buffer
  if provider then
    local previous = provider.transform_items
    provider.transform_items = function(ctx, items)
      if previous then items = previous(ctx, items) end
      if vim.bo.filetype ~= "ncl" then return items end
      return vim.tbl_filter(function(item)
        return not require("tree_sitter_ncl.snippets").is_catalog_trigger(item.label)
      end, items)
    end
  end
end

return M
