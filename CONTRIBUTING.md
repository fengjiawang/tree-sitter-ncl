# 开发说明

## 代码脉络

1. `grammar.js` 描述 NCL 语法；`src/scanner.c` 处理 `1.eq.2` 与尾随小数点的词法歧义。
2. Tree-sitter CLI 生成 `src/parser.c`、`src/grammar.json`、`src/node-types.json` 和头文件。
   这些生成产物随 Git 提交，用户通过 `make` 直接编译成 `ncl.so`。
3. `queries/` 根据语法节点定义编辑器行为；`highlights.scm` 由基础查询和名称词表生成。
4. `lua/tree_sitter_ncl/init.lua` 是唯一的常规 Neovim 入口；`setup()` 加载解析器和查询，在 NCL 缓冲区启用功能。
   `ftdetect/ncl.lua` 为 lazy.nvim 首次按文件类型加载提供 `.ncl` 检测。
5. `snippets.lua` 将项目模板和当前缓冲区的函数定义交给 LuaSnip；`blink.lua` 为已安装的 blink.cmp 接入 NCL 专用候选。
   不调用原个人 snippets 目录的加载器，不为其他文件类型更换补全引擎。
6. `examples/neovim*.lua` 仅保留手动试用和旧配置兼容用途，不再承载主要实现。

## 构建和测试

开发需要 Node.js/npm、Tree-sitter CLI 0.27.0、C 编译器和 make。
只有修改语法/生成文件或运行 corpus 时才需要 CLI；普通插件安装只需要 C 编译器和 make。

```sh
npm ci
npm run generate       # 更新高亮和解析器生成文件
npm test               # 语法 corpus，包含预期错误用例
npm run build          # 等同 make；不会下载或重装 CLI
npm run check          # 加上示例解析和原生 Neovim 检查
npm run check:editor   # 加上 LuaSnip、缩进、blink.cmp 和 lazy.nvim 安装入口验证
npm run bench          # 单独测量 NCL 初始化及未修改缓冲区的重复刷新耗时
```

原生检查需要 Neovim。编辑器检查默认从 Neovim 数据目录下的 `lazy/` 查找已安装插件，
可用 `NCL_LUASNIP_PATH`、`NCL_TREESITTER_PATH`、`NCL_LAZY_PATH`、`NCL_BLINK_PATH` 指定 checkout。
测试不加载个人 `init.lua` 或 NCL 配置；不会运行示例中的业务调用。

模板使用 LuaSnip 的 `SnippetProxy`：触发词、说明和上下文立即注册，展开时才解析占位符。
函数调用模板按缓冲区和修改计数缓存；有效函数签名没有变化时不重新注册，避免反复清空补全缓存。
`test:snippet-loading` 会对照原来的立即解析方式核对全部模板的展开文本，并检查函数签名变化和缓冲区切换时的缓存失效。
性能比较应在多个独立 Neovim 进程中取中位数；`bench` 不包含完整个人配置、UI 绘制或所有插件的启动时间。

新语法先添加 `test/corpus/` 用例。更新快照时检查树形结构和字段，不能将意外 ERROR 当作正确结果。
提交语法变更时一并提交生成文件。机器相关的 `ncl.so`、缓存和 `node_modules/` 不提交。

## 词表与模板

- `data/ncl-vocabulary.json` 保存函数、资源、色表和字体名称。
- `data/ncl-snippets.json` 保存模板及参数占位符。项目本身不能从语法规则推断外部库函数的签名。
- `scripts/generate-highlights.js` 从 `queries/highlights-base.scm` 和词表生成 `queries/highlights.scm`。
- `scripts/import-vocabulary.js`、`scripts/import-snippets.js` 是维护者主动迁移旧数据的工具，安装和运行时均不调用。

```sh
node scripts/import-vocabulary.js /path/to/ncl-snippets /path/to/ncl.lua
node scripts/import-snippets.js /path/to/ncl-snippets
npm run generate
```

默认包含 3,470 个模板触发项。`setup { snippets = { catalog = false } }` 只生成当前文件中有定义的函数/过程调用模板。
候选按 Tree-sitter 上下文过滤：函数/代码模板在字符串和注释中禁用，色表/字体模板只在字符串中显示。

## 语法约定与边界

- `f(x)` 与 `a(i)` 语法相同，统一使用 `application_expression`，不凭语法假定它一定是函数。
- 依据 NCAR 源码，一元负号和 `.not.` 优先于乘方，乘方左结合，`.or.` 与 `.xor.` 同级。
- 行注释使用 `;`，块注释使用 `/; … ;/`，while 循环使用 `do while (...)`。
- 字符串转义是编辑友好扩展；不保证每一种写法都与 NCL 运行时完全一致。
- 不提供类型/维度检查、跨文件符号分析、完整遗留交互语法、WASM 或语言绑定。
- 当前 Makefile 面向 macOS/Linux。Windows 原生构建尚未提供。

参考 [NCAR 语法源码](https://github.com/NCAR/ncl/blob/develop/ni/src/ncl/ncl.y)、
[词法源码](https://github.com/NCAR/ncl/blob/develop/ni/src/ncl/ncl.l)、
[NCL 参考手册](https://www.ncl.ucar.edu/Document/Manuals/Ref_Manual/)。
