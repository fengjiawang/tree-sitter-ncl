# tree-sitter-ncl

[NCAR Command Language](https://www.ncl.ucar.edu/)（NCL）的 Tree-sitter 解析器与 Neovim 插件。
提供语法高亮、代码折叠、缩进，以及 LuaSnip 模板和当前文件函数调用补全。

## 安装

支持 macOS / Linux，需要 **Neovim 0.11+、C 编译器和 make**。
仓库包含生成好的 C 源码，安装时不需要 Node.js、npm 或 Tree-sitter CLI。

将以下配置加入 lazy.nvim：

```lua
{
  "fengjiawang/tree-sitter-ncl",
  ft = "ncl",
  build = "make",
  dependencies = { "nvim-treesitter/nvim-treesitter", "L3MON4D3/LuaSnip" },
  opts = {},
}
```

安装后打开 `.ncl` 文件即可启用；插件会将该扩展名识别为 NCAR NCL，而非 Neovim 默认的 Nickel。
使用 `:InspectTree` 查看语法树，使用 `gg=G` 重新缩进。
更新后重启 Neovim；如果缺少解析器，运行 `:Lazy build tree-sitter-ncl`。

- **缩进**使用新版 nvim-treesitter，宽度跟随 `shiftwidth`。
- **模板**随项目分发，不读取个人 snippets 目录；LuaSnip 负责展开与参数跳转。
- 已安装 **blink.cmp** 时，自动为 NCL 接入 LuaSnip 候选和参数跳转，其他文件类型保持原配置。
  其他补全插件需自行启用 LuaSnip 补全源；本插件不安装补全菜单或修改快捷键。

若从旧版配置迁移，请移除旧 NCL 正则高亮、缩进和 snippets 目录加载逻辑，避免重复。

## 可选配置

默认启用高亮、折叠、缩进和模板。可在 `opts` 中单独关闭，例如：

```lua
opts = {
  folds = false,
  snippets = { catalog = false }, -- 只从当前文件的函数/过程定义生成调用模板
}
```

`highlight`、`indent`、`snippets` 也可设为 `false`。
仅需解析器时可关闭缩进和模板，并移除对应依赖。

## 项目结构

| 位置 | 内容 |
| --- | --- |
| `grammar.js`、`src/` | 语法规则、外部扫描器、生成的 C 解析器 |
| `queries/` | 高亮、折叠、缩进、函数标签查询 |
| `lua/tree_sitter_ncl/` | Neovim 入口、LuaSnip 和可选 blink.cmp 集成 |
| `data/` | 函数词表及模板数据，不依赖个人配置路径 |
| `test/`、`examples/` | 语法与编辑器回归测试、NCL 示例 |

解析器覆盖常用控制流、函数定义、数组/坐标切片、文件变量、元数据和绘图资源块。
当前仍是原型，不检查类型、维度或参数数量，也不会运行 NCL 程序。
语法错误下的缩进为实验性支持；跨文件函数索引尚未实现。

开发、测试与语法说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。
