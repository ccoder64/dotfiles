# Dotfiles

这是一个统一管理 macOS 和 Linux 环境配置的仓库,旨在提供一个现代化、高效且跨平台的命令行工作环境.

## 核心理念

- **模块化:** 配置按功能拆分到 `lib/` 目录下,由 `.bashrc` 按需加载,结构清晰,易于管理.
- **自动化安装:** 通过 `./install.sh` 脚本一键完成环境部署,包括软件安装、配置链接等.
- **跨平台兼容:** 无缝支持 macOS 和 Linux,并为不同系统提供特定的安装逻辑.
- **智能适配:** 安装脚本能自动检测运行环境 (如操作系统、所在地区),并选择最优的安装方式 (如包管理器、镜像源).

## 功能亮点

此仓库不仅仅是配置的堆砌,更是一套精心整合的现代化工具集:

- **增强 Shell:**
    - **Bash** 作为基础 Shell.
    - **[Starship](https://starship.rs/)**: 提供美观、快速且高度可定制的跨 Shell 提示符.
    - **[zoxide](https://github.com/ajeetdsouza/zoxide)**: 更智能的 `cd` 命令,能够 "学习" 您的习惯,快速跳转到常用目录.
- **高效 Git 工作流:**
    - **[git-delta](https://github.com/dandavison/delta)**: 强大的 `diff` 和 `blame` 查看工具,语法高亮,并排视图.
    - **[tig](https://github.com/jonas/tig)**: 优秀的 Git 文本模式界面,让日志查看、提交和分支管理更直观.
    - **大量实用别名**: 在 `lib/aliases.sh` 中预设了 `glog`, `gds`, `gcb` 等高效别名,简化常用操作.
- **现代化的命令行工具:**
    - **[eza](https://github.com/eza-community/eza)**: `ls` 的现代替代品,图标支持、颜色丰富、Git 集成.
    - **[bat](https://github.com/sharkdp/bat)**: `cat` 的替代品,支持语法高亮和 Git 集成.
    - **[ripgrep (rg)](https://github.com/BurntSushi/ripgrep)**: 极速的文件内容搜索工具,`grep` 的强力替代.
    - **[fzf](https://github.com/junegunn/fzf)**: 通用的命令行模糊搜索器,可与众多工具集成.
    - **[glow](https://github.com/charmbracelet/glow)**: 在终端中排版阅读 Markdown,也能浏览仓库中的文档.
    - **[yq](https://github.com/mikefarah/yq)**: 使用类似 jq 的语法查询和处理 YAML 配置.
    - **[dust](https://github.com/bootandy/dust)**: 用目录树和占用比例定位磁盘空间消耗.
- **终端工作区:**
    - **[Herdr](https://herdr.dev/tui/)**: 管理终端工作区、标签页和面板,支持编码 Agent 与持久会话.
- **强大的文本编辑器:**
    - **Vim** 作为主力编辑器,通过 `vim-plug` 管理插件.
    - 预装了代码格式化、Git 集成、快速导航等实用插件.

## 如何安装

在新机器上,只需克隆仓库并执行安装脚本:

```bash
git clone https://github.com/in64/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./install.sh
```

脚本会自动完成以下所有工作:
1.  **检测操作系统** (macOS 或 Linux).
2.  **准备系统依赖**: Linux 先通过 `apt` (Debian/Ubuntu) 或 `dnf` (RHEL/Rocky/Alma) 安装 curl、证书、jq、rsync 等依赖; root 直接安装,普通用户通过 sudo 安装. macOS 使用系统 curl,并在需要时安装和初始化 Homebrew.
3.  **智能网络优化**: 如果检测到在中国大陆,将自动为 Homebrew、GitHub、vim-plug 等设置镜像或代理,加速下载. Linux 的地区检测在 curl 安装完成后执行.
4.  **安装工具**: macOS 使用 Homebrew; Linux 将 GitHub Release 中缺失或不可用的工具安装到 `~/.local/bin`. 下载和解压先在临时目录完成,运行检查通过后再放入目标位置.
5.  **链接配置文件**: 优先创建硬链接,跨文件系统等情况下回退为复制. Git 更新后重新执行安装,即可重新应用配置.
6.  **同步 Vim 插件**: 自动下载 `vim-plug`,以无交互方式同步插件并清理已从配置删除的插件.

安装完成后, 重启 Shell 或运行 `source ~/.bashrc` 即可生效.

脚本可以重复执行. 已可运行的 GitHub 二进制和已有 Herdr 会复用; fzf 还会检查 `--bash` 集成是否可用. 系统包和 Vim 插件仍沿用各自的安装/更新方式. 不要求预装 curl、jq 或 rsync,但系统包安装需要相应权限,包源与下载地址需要可访问.

也可以显式指定下载代理前缀:

```bash
PREFIX_PROXY=https://spu.seiya.dev/ ./install.sh
```

## 目录结构

- `install.sh`: 主安装脚本,是整个自动化流程的入口.
- `home/`: 存放所有需要链接到 `$HOME` 目录的配置文件.
    - `.bashrc`: Shell 的主配置文件,负责加载 `lib/` 中的模块.
    - `.gitconfig`: Git 全局配置,集成了 delta 并通过 `include` 加载私有配置.
    - `.vimrc`: Vim 配置文件及插件列表.
    - `.config/`: 存放遵循 XDG 规范的配置文件,如 `starship`, `htop` 等.
- `lib/`: 存放被 `.bashrc` 加载的模块化 Shell 脚本.
    - `aliases.sh`: 定义了大量提高效率的别名.
    - `exports.sh`: 设置环境变量.
    - `functions.sh`: 定义通用的 Shell 函数.
    - `path.sh`: 管理 `PATH` 环境变量.

## 配置详情

本节详细介绍各个工具的配置亮点,帮助您快速上手.

### Shell 环境 (Bash + Starship)

- **`~/.bashrc`**: 作为 Shell 的入口,负责加载 `lib/` 目录下的所有模块化脚本,并初始化 `starship` 和 `zoxide`.
- **`lib/functions.sh`**: 定义了 `mkcd` 函数,用于创建目录并立即进入.
- **`~/.config/starship.toml`**: 配置 [Starship](https://starship.rs/) 提示符,使其简洁且信息丰富.

#### Shell 别名 (`lib/aliases.sh`)

| 别名 | 命令 | 说明 |
|---|---|---|
| `g` | `git` | `git` 命令的缩写. |
| `ga` | `git add` | 添加文件到暂存区. |
| `gaa` | `git add --all` | 添加所有变动文件到暂存区. |
| `gap` | `git add -p` | 以交互方式添加文件的部分内容. |
| `gb` | `git branch` | 列出、创建或删除分支. |
| `gc` | `git commit -v` | 提交暂存的更改 (带详细 diff). |
| `gca` | `git commit -v -a` | 提交所有已跟踪文件的更改. |
| `gcam` | `git commit -v -a -m` | 附带消息提交所有已跟踪文件的更改. |
| `gcm` | `git commit -m` | 附带消息提交暂存的更改. |
| `gco` | `git checkout` | 切换分支或恢复工作区文件. |
| `gcb` | `git checkout -b` | 创建并切换到新分支. |
| `gd` | `git diff` | 查看工作区与暂存区的差异. |
| `gds` | `git diff --staged` | 查看暂存区与上次提交的差异. |
| `glog` | `git log --graph ...` | 以美化的图形格式显示提交日志. |
| `gp` | `git push` | 推送提交到远程仓库. |
| `gpf` | `git push --force-with-lease` | 安全地强制推送. |
| `gpl` | `git pull --rebase` | 拉取远程更改并变基. |
| `gs` | `git status` | 显示工作区状态. |
| `ls` | `eza` | `ls` 的现代替代品 (如果 `eza` 不存在则为 `ls --color=auto`). |
| `ll` | `eza -l` | 以长列表格式显示文件. |
| `la` | `eza -la` | 以长列表格式显示所有文件 (包括隐藏文件). |
| `cd` | `cd -P` | 切换目录,解析物理路径. |
| `vi` | `vim` | 使用 `vim` 打开文件. |
| `grep` | `grep --color=auto -I` | 带颜色的 `grep`, 忽略二进制文件. |
| `pkill` | `pkill -u $USER` | 杀死当前用户的所有进程. |
| `pw` | `pwd` | 显示当前工作目录. |
| `cat` | `bat` | `cat` 的现代替代品 (如果 `bat` 不存在则无此别名). |

### 阅读文档、处理配置和定位空间占用

```bash
glow -p README.md                    # 分页阅读排版后的 Markdown
glow                                # 浏览当前目录或 Git 仓库中的 Markdown
yq '.services | keys' compose.yaml   # 列出 Compose 服务
yq '.services.web.image' compose.yaml
dust -d 2 .                         # 查看两层目录的空间占用
```

### 文件与内容检索

- **`Ctrl-T`**: 用 rg 列出项目文件,遵循忽略规则并包含未被忽略的隐藏文件; bat 预览前 300 行. 目录切换继续使用 fzf 的 `Alt-C` 或 zoxide.
- **`Ctrl-R`**: 使用 fzf 搜索历史命令.
- **`rgi <表达式> [文件或目录...]`**: 搜索正文,预览匹配行,回车后在 Vim 中打开对应文件和行; 取消选择不会打开编辑器.
- 已设置的 `FZF_DEFAULT_COMMAND`、`FZF_CTRL_T_COMMAND` 和非空 `FZF_CTRL_T_OPTS` 会保留.

```bash
rgi 'install_from_github'       # 搜索当前目录
rgi 'timeout|retry' lib         # 限定目录
```

### Git 工作流

- **`~/.gitconfig`**: 核心配置文件,集成了 `delta` 并通过 `include` 加载 `~/.gitconfig.local` 中的私有配置.
- **`~/.tigrc`**: 为 [Tig](https://github.com/jonas/tig) 配置了视图列和颜色主题,优化了日志浏览体验.

#### Git 别名 (`~/.gitconfig`)

这些别名需要在 `git` 命令后使用, 例如 `git lg`.

| 别名 | 命令 | 说明 |
|---|---|---|
| `lg` | `log --color --graph --pretty` | 以图形化方式显示简化的日志. |
| `df` | `difftool` | 使用配置的 `difftool` (delta) 查看差异. |
| `ci` | `commit` | 提交. |
| `co` | `checkout` | 切换分支. |
| `st` | `status` | 查看状态. |
| `br` | `branch` | 分支操作. |
| `last` | `log -1 HEAD` | 显示最近一次的提交. |
| `ls` | `ls-files` | 列出 Git 跟踪的文件. |

### Vim 编辑器 (`~/.vimrc`)

通过 `vim-plug` 管理,提供了现代化的编辑体验. **领键 (Leader) 设置为分号 `;`**.

#### 插件列表及说明

| 插件 | 功能说明 |
|---|---|
| `junegunn/fzf` | fzf 的 Vim 基础 runtime,复用安装器提供的 fzf 二进制. |
| `junegunn/fzf.vim` | 模糊搜索神器,用于快速查找文件、缓冲区、历史记录等. |
| `ludovicchabant/vim-gutentags` | 在后台自动管理 `tags` 文件,实现无缝的代码定义跳转. |
| `bling/vim-airline` | 一个高度可定制的美观状态栏,显示各种有用信息. |
| `vim-airline/vim-airline-themes` | 为 `vim-airline` 提供多种主题样式. |
| `nathanaelkane/vim-indent-guides` | 以可视化的方式显示缩进线,帮助保持代码整洁. |
| `airblade/vim-gitgutter` | 在编辑器侧边栏 (sign column) 显示当前文件的 Git diff 信息 (增/删/改). |
| `vim-scripts/a.vim` | 在 C/C++ 的头文件 (`.h`) 和源文件 (`.cpp`) 之间快速切换. |
| `junegunn/vim-easy-align` | 一个简单的对齐工具,可以按等号、逗号等符号对齐代码块. |
| `easymotion/vim-easymotion` | 极大地增强了屏幕内的光标移动能力,实现指哪打哪. |
| `scrooloose/nerdcommenter` | 提供了强大的代码注释功能,支持多种语言和注释风格. |
| `google/yapf` | Google 出品的 Python 代码格式化工具. |
| `rhysd/vim-clang-format` | 集成了 `clang-format`, 用于格式化 C, C++, Obj-C 代码. |

#### 主要快捷键

| 快捷键 | 模式 | 功能 |
|---|---|---|
| `<Leader>` | - | 设置为 **分号 (`;`)**. |
| `<F4>` | Normal | 执行 `q` 寄存器中的宏. |
| `<C-N>` | Normal | 切换到下一个标签页 (`:tn`). |
| `<Leader>ch` | Normal | 切换头文件/源文件 (`:A`). |
| `<C-]>` | Normal | 跳转到标签定义 (当有多个匹配时, `g<C-]>` 会列出所有). |
| `<Enter>` | Visual | 使用 EasyAlign 对齐选中的代码. |
| `ga` | Normal/Visual | EasyAlign 的快捷方式. |
| `s<char><char>` | Normal | 使用 EasyMotion 快速跳转到以这两个字符开头的位置. |
| `mm` | Normal | 跳转到下一个 Git Hunk (修改块). |
| `mn` | Normal | 跳转到上一个 Git Hunk. |
| `mr` | Normal | 撤销当前光标所在 Hunk 的修改. |
| `<C-p>` | Normal | 使用 fzf 模糊搜索 Git 仓库中的文件 (`:GFiles`). |
| `<Leader>b` | Normal | 使用 fzf 模糊搜索已打开的缓冲区 (`:Buffers`). |
| `<Leader>f` | Normal | 使用 fzf 和 ripgrep 搜索项目中的文本内容 (`:Rg`). |
| `<C-J>` | Normal/Insert | 格式化当前代码 (支持 Python, C, C++). |
| `:JsonFormat` | Command | 将当前文件作为 JSON 进行格式化. |

### Herdr 终端工作区

直接启动或接入已有会话,也可以使用命名会话区分项目:

```bash
herdr
herdr --session project
```

仓库使用 Herdr 的默认配置,不自动启动会话或安装 Agent 集成. 快捷键和设置见 [Herdr 文档](https://herdr.dev/tui/docs/). 安装器不再安装 Tmux、分发其配置或加载 Vim 的 Tmux 插件; 已有 Tmux 安装和会话不会被主动删除或停止.

### 其他配置文件

- **`.editorconfig`**: 为不同的文件类型定义了一致的编码风格 (如缩进大小、字符集), 确保在不同编辑器中代码风格统一.
- **`.config/htop/htoprc`**: `htop` 的配置文件, 保存了列的显示、排序方式、颜色主题等界面设置. 通常由 `htop` 自身修改.

## 自定义与私有配置

为了在不修改核心 dotfiles 的前提下进行个性化配置,本项目支持以下方式:

- **Git 私有配置**:
  在 `~/.gitconfig.local` 文件中添加您的个人信息 (用户名, 邮箱等). 此文件已被 `.gitconfig` 默认包含,并被 `.gitignore` 忽略.
  ```ini
  # ~/.gitconfig.local
  [user]
      name = Your Name
      email = your.email@example.com
  ```

- **Shell 私有配置**:
  可以创建一个 `~/.bashrc.local` 文件 (需手动创建),用于存放您不想提交到仓库的个人别名、函数或环境变量. 然后在 `home/.bashrc` 文件末尾添加 `source ~/.bashrc.local` 来加载它.

## 开发检查

```bash
bash -n install.sh
shellcheck install.sh home/.bashrc lib/*.sh
python3 -m unittest discover -s tests -v
```

回归测试在临时 HOME 和模拟包管理器下运行,不安装系统软件或改写当前用户配置; 实际发行版的安装结果需要在对应系统中验证.
