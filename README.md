# tree-sitter-ncl

NCAR Command Language（NCL）的 Tree-sitter 原型，用于语法树分析和 Neovim 编辑。
包含可生成的语法、生成后的 C 解析器、一个小型外部扫描器、高亮/折叠/标签/缩进查询、LuaSnip 桥接、示例和回归测试。
目前是本地开发项目，尚未发布到 npm 或提交至 nvim-treesitter 的语言列表。

## Install

### Requirements

- Neovim 0.11 or newer
- Node.js and npm
- A C compiler
- Tree-sitter CLI 0.27.0
- LuaSnip for snippet completion
- nvim-treesitter for Tree-sitter indentation

### lazy.nvim

Add this plugin spec to your lazy.nvim plugins directory:

```lua
return {
  {
    "fengjiawang/tree-sitter-ncl",
    build = "npm install && npm run build",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "L3MON4D3/LuaSnip",
      "saghen/blink.cmp",
    },
    config = function(plugin)
      dofile(plugin.dir .. "/examples/neovim.lua")
      dofile(plugin.dir .. "/examples/neovim-snippets.lua")
    end,
  },
}
```

Restart Neovim after installation and open an `.ncl` file. The spec builds and loads
the parser, syntax queries, Tree-sitter indentation, the bundled LuaSnip catalog, and
the blink.cmp completion source. It does not read any external snippets directory.
If the plugin was already installed with an older spec, run `:Lazy build tree-sitter-ncl`
once after updating the configuration; the build also repairs an older incomplete
`tree-sitter-cli` installation.

The repository provides native Neovim examples for debugging or setups without
lazy.nvim. Build the parser first, then load the parser and LuaSnip bridge:

```vim
:luafile /path/to/tree-sitter-ncl/examples/neovim.lua
:luafile /path/to/tree-sitter-ncl/examples/neovim-snippets.lua
```

The snippets bridge uses the catalog bundled in `data/ncl-snippets.json` and does not
read the original snippets directory.

## 构建与验证

需要 Node.js、C 编译器和 Tree-sitter CLI 0.27.0；Neovim 集成示例需要 Neovim 0.11+。
本机实际验证环境：Tree-sitter 0.27.0、Node.js 18.20.5、Neovim 0.12.4、macOS arm64。

```sh
cd tree-sitter-ncl

# 已有 tree-sitter 0.27.0 时，可直接使用，不必重新安装。
tree-sitter --version
npm run check
```

若没有 CLI，先运行 `npm install` 安装 package.json 中固定版本的开发依赖。
`npm run check` 依次生成高亮和解析器、运行 corpus、解析示例、编译 `ncl.so`，再执行无用户配置的 Neovim 集成测试。
缓存写入项目 `.cache/`，编译结果 `ncl.so` 不进入版本控制。示例脚本只进行解析，不执行其中的 NCL 调用。

也可以分步运行：

```sh
npm run generate
npm test
npm run test:examples
npm run build
npm run test:neovim

# 可选编辑功能的完整验证：需要 LuaSnip 和新版 nvim-treesitter
npm run check:editor

# 查看带字段名的语法树
XDG_CACHE_HOME="$PWD/.cache" tree-sitter parse examples/weather.ncl
```

CLI 若提示未配置 parser directories，在此仓库根目录运行仍能解析当前 grammar；不需要为此更改全局配置。
`src/parser.c`、`src/grammar.json`、`src/node-types.json` 和 `src/tree_sitter/` 均为生成产物，修改 `grammar.js` 后重新生成。

## 原型覆盖范围

| 类别 | 已覆盖的语法 |
| --- | --- |
| 语句 | `begin/end`、赋值 `=`、重新赋值 `:=`、调用、`load`、`external`、`return`、退出与记录命令 |
| 控制流 | `if/then/else/end if`、`elseif`、嵌套 `else if`、计数循环和步长、`do while`、`break/continue`、单行块与条件语句 |
| 定义 | `function`、`procedure`、类型约束、`[*]`/`[2]` 维度约束、`local` |
| 表达式 | 数字及类型后缀、科学计数法、字符串、布尔值、Missing、算术/逻辑/选择/矩阵运算、`new` |
| 数组和列表 | `(/…/)`、`[/…/]`、索引、切片及步长、坐标 `{…}`、命名维度 `lat\|:`、列表 `[i]` |
| 元数据与文件 | `@` 属性、`!` 维名、`&` 坐标、`->` 文件变量、`=>` 文件组、`$…$` 动态名称、`lib::func()` |
| 图形对象 | `create/end create`、`setvalues/end setvalues`、`getvalues/end getvalues` |
| 词法 | `;` 行注释、`/; … ;/` 块注释、反斜杠续行、CRLF、无末尾换行、`1.eq.2` 这种无空格运算 |

NCL 的 `f(x)` 和 `a(i)` 无法仅凭语法区分是函数调用还是数组索引。因此都使用
`application_expression`，提供 `function` 和 `arguments` 字段；`function` 在这里表示被应用的表达式，不承诺它是函数。
高亮通过现有词表识别已知函数，未知名字在独立调用语句中使用函数颜色；其他位置保持变量颜色。
这也意味着 `x = user_function(a)` 中未收录的用户函数暂时使用变量颜色。

运算符优先级参照 NCAR 解析器源码：一元负号和 `.not.` 优先级最高，乘方左结合，`.or.` 与 `.xor.` 同级。
例如 `-3^2^4` 的树形分组是 `((-3)^2)^4`。`src/scanner.c` 只处理尾随小数点的数字，避免把 `1.eq.2` 错读为 `1.` 和 `eq`。

## 在当前 Neovim 中试用

先运行 `npm run build`，然后在 Neovim 中执行：

```vim
:luafile /path/to/tree-sitter-ncl/examples/neovim.lua
:edit /path/to/tree-sitter-ncl/examples/weather.ncl
:set filetype=ncl
:InspectTree
```

该示例直接使用 Neovim 原生 Tree-sitter API，加载当前仓库的解析器和查询。
它启用高亮与基于语法树的折叠，设置 `; %s` 注释格式，并清除现有 `ncl.lua` 记录在
`vim.w.ncl_syntax_matches` 中的正则高亮。窗口/缓冲区切换后也会处理原配置重新添加的匹配。
自定义函数使用 `@function.custom.ncl`，链接到原来的 `Special` 颜色。
若能加载本机新版 `nvim-treesitter`，示例同时启用其 `indentexpr()`，使用项目的 `queries/indents.scm` 替代原来的 `NclIndent()`。
未加载缩进插件时，仍可使用原生高亮与折叠，缩进选项保持原样。

此操作仅影响当前 Neovim 会话，项目没有改写 `~/.config/nvim/`。
若要持久启用，可在自己的配置加载阶段添加上述 Lua 文件的 `dofile(...)` 调用；更新解析器后重启 Neovim 再加载，避免旧动态库仍留在进程中。

如果希望通过本机所安装的新版 nvim-treesitter 管理安装，它的本地解析器配置使用：

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").ncl = {
      install_info = {
        path = "/path/to/tree-sitter-ncl",
        queries = "queries",
      },
    }
  end,
})
```

然后使用 `:TSInstall ncl`，并自行启用 `vim.treesitter.start()`。
这段配置依据本机新版插件 README 编写，未执行其安装流程；已经实际测试的是上面的原生加载方式。
旧版插件的 `get_parser_configs()` API 不适用于本机这版插件。

## 参考资料与词表

构建流程按本仓库 `docs/src/creating-parsers/` 的教程组织：语法骨架 → `generate` → `test/corpus` → `parse` → 查询与集成验证。
原有 `.gitignore` 中的 `docs/` 忽略规则已保留，教程原文没有修改。

编辑习惯和名称词表参考：

- Your local NCL snippets directory
- Your local NCL Neovim configuration

`data/ncl-vocabulary.json` 保存独立快照，含 1,443 个函数、23 个自定义函数、1,642 个资源相关词条、270 个色表名称、43 个字体名称。
高亮查询使用函数和自定义函数词表，资源名按语法位置高亮。
补全与模板展开由下面的可选 LuaSnip 桥接提供；本项目不实现补全菜单或按键映射。
因此在其他机器构建无需访问这些个人配置路径。

更新词表和高亮：

```sh
node scripts/import-vocabulary.js \
  /path/to/your/ncl-snippets \
  /path/to/your/ncl.lua
npm run generate
```

`queries/highlights.scm` 由 `queries/highlights-base.scm` 和词表生成；请编辑源文件。
Snippets 是编辑模板，不是正式语言规范。核对后没有沿用以下写法：

- `keywords.json` 的模块头模板以 `!` 开头，这是 Fortran 风格，NCL 注释使用 `;`。
- `dowhile` 模板中的 `do (...)` 缺少 `while`，这里要求 `do while (...)`。
- `ncl.lua` 用 `/* … */` 匹配块注释，官方 NCL 词法定义使用 `/; … ;/`。

补充核对的官方来源：

- [Tree-sitter 原型所依据的 NCAR 语法源码 ncl.y](https://github.com/NCAR/ncl/blob/develop/ni/src/ncl/ncl.y)
- [NCAR 词法源码 ncl.l](https://github.com/NCAR/ncl/blob/develop/ni/src/ncl/ncl.l)
- [NCL 语句参考](https://www.ncl.ucar.edu/Document/Manuals/Ref_Manual/NclStatements.shtml)
- [NCL 表达式参考](https://www.ncl.ucar.edu/Document/Manuals/Ref_Manual/NclExpressions.shtml)
- [NCL 数据类型参考](https://www.ncl.ucar.edu/Document/Manuals/Ref_Manual/NclDataTypes.shtml)

## 测试与后续边界

当前提供 39 个 corpus 用例（含 10 个预期错误用例）、两个综合示例和 45 项原生 Neovim 集成检查。
集成检查额外验证字段含义、运算符分组、字符串/注释中不误判函数名、折叠和标签查询，以及增量编辑结果与重新解析一致。
新语法应先添加最小 corpus 用例，再修改 grammar；更新快照时需检查树形结构，不应把意外 ERROR 作为正确结果接受。

这不是 NCL 编译器：不进行类型检查、名字解析、维度兼容性或函数参数数量检查，也未运行 NCL 气象业务脚本。
语法有意对元数据访问链、图形类名称等保持宽松。字符串接受现有编辑器配置中的反斜杠转义写法，属于编辑友好扩展；不保证每种字符串写法与 NCL 运行时完全一致。
暂不覆盖所有遗留/交互命令、复合数据类型声明、旧式方括号 `new[...]` 等低频写法，也未提供 Rust/Python/Node 绑定、WASM 包或完整语义 locals 查询。
在真实业务脚本上扩大 corpus 是下一步验证重点。

## LuaSnip：不依赖原来的 snippets 目录

`lua/tree_sitter_ncl/snippets.lua` 提供两种数据来源：

1. **项目内模板目录数据**：`data/ncl-snippets.json` 保存已迁入项目的 3,470 个触发项，包含函数参数占位符、说明、自定义绘图模板、资源、色表和字体。
   运行时只读取这份项目数据，不读取 `~/.config/nvim/snippets/`，也不调用 VS Code snippet 文件加载器。
   迁入的副本修正了 `dowhile` 缺少 `while`、模块说明头使用 `!` 的问题，原文件保持不变。
2. **当前缓冲区语法树**：识别 `function/procedure` 定义及其参数，在进入缓冲区或进入/退出插入模式时刷新调用模板。
   例如定义 `function my_anomaly(x:numeric, baseline:numeric)` 后，可以展开 `my_anomaly(x, baseline)`，两个参数都是可跳转的占位符。
   只读取当前文件，不跨文件索引，也不推断外部库的函数签名。

Tree-sitter 还提供展开上下文：代码和函数模板在字符串/注释中禁用，色表和字体模板只在字符串中显示。
补全菜单必须支持 LuaSnip snippet 源；参数跳转继续使用你现有的 LuaSnip 快捷键。

加载方法：

```vim
:luafile /path/to/tree-sitter-ncl/examples/neovim.lua
:luafile /path/to/tree-sitter-ncl/examples/neovim-snippets.lua
```

第二个示例会通过已安装的 lazy.nvim 加载 LuaSnip；如果没有 lazy.nvim，请先把 LuaSnip 加入 runtimepath。
启用这条加载路径时，应从自己的原 `ncl.lua` 中移除 `load_ncl_snippets()` 调用，否则旧加载器仍会读取原目录，并出现两份重复候选。
这里没有自动修改个人配置，也没有删除原 snippets；首次切换后重启 Neovim，避免之前已加载的旧模板继续驻留。

若只想用语法树，完全不读取项目模板数据，可以使用：

```lua
require("tree_sitter_ncl.snippets").setup { catalog = false }
```

这种模式只能生成当前文件中有定义的函数/过程调用。单靠语法规则，无法得知 `gsn_panel` 的参数名，也无法推导出 `initplot` 这样的多行绘图模板。
因此默认模式将模板元数据随项目分发；不应把模板展开误认为解析器自动推导出了全部库函数知识。

今后只有主动刷新迁移数据时才需要原目录：

```sh
node scripts/import-snippets.js /path/to/your/ncl-snippets
```

## Tree-sitter 缩进

`queries/indents.scm` 使用新版 nvim-treesitter 的 `@indent.begin`、`@indent.branch`、`@indent.end` 等捕获，按语法节点计算缩进。
原生 Tree-sitter 解析器本身不会执行缩进，必须由编辑器的缩进引擎消费查询。
当前支持块、循环、条件分支、函数体、图形资源块、数组/参数续行；`end`、`else`、`elseif` 返回相应层级。
函数声明、`local` 和函数的 `begin` 保持同一级，遵循 NCL 常见写法。缩进宽度跟随 `shiftwidth`。
多行注释保留已有格式；未闭合的块提供基本错误节点回退，但任意错误代码的缩进仍属于实验性功能。

如果自行加载解析器和查询，启用方式为：

```lua
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
```

`npm run test:editor` 使用本机已安装的 LuaSnip 与 nvim-treesitter，在 `-u NONE` 的 Neovim 中验证 77 项编辑功能检查，
包括实际 snippet 展开、参数跳转、语法树生成模板、上下文过滤、`gg=G` 格式化和重复缩进的一致性。
测试不加载个人 `init.lua`、原 `ncl.lua` 或原 snippets 目录。
其他机器可用 `NCL_LUASNIP_PATH` 和 `NCL_TREESITTER_PATH` 指向插件 checkout；这些是测试依赖，不打包在解析器中。
