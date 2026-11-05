#!/usr/bin/env bash

set -euo pipefail

# 获取脚本所在目录
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
HOME=${HOME:=$(eval echo ~)}
PREFIX_PROXY="${PREFIX_PROXY:-}"
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

WORK_DIR=$(mktemp -d "$HOME/.local/bin/.dotfiles.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

# 通用辅助函数
# 日志函数
info() { printf " [34m➜  %s[0m\n" "$*"; }
warn() { printf " [33m➜  %s[0m\n" "$*"; }
error() { printf " [31m✖  %s[0m\n" "$*" >&2; exit 1; }

# 在系统依赖安装完成后检测地区, 不要求用户预先安装 curl.
configure_network() {
    if [[ -z "$PREFIX_PROXY" ]] && \
        curl -fsSL -m 5 https://ip.seiya.dev/country 2>/dev/null | grep -qx 'CN'; then
        info "📍 检测到在中国, 将为部分网络请求启用代理和镜像."
        PREFIX_PROXY="https://spu.seiya.dev/"
        # 为 Homebrew 设置镜像,加速软件包下载
        export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
    fi
}

# Linux 容器可以直接以 root 运行, 不依赖 sudo.
as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        command -v sudo &>/dev/null || error "安装系统依赖需要 root 权限或 sudo."
        sudo "$@"
    fi
}

# 根据工具名和系统架构, 获取对应的架构关键字
get_arch_name() {
    local tool=${1:-default}
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        case "$tool" in
            fzf|rage|glow|yq) echo "arm64" ;;
            *)        echo "aarch64" ;;
        esac
    elif [[ "$arch" == "x86_64" ]]; then
        case "$tool" in
            fzf|fastfetch|yq) echo "amd64" ;;
            *)             echo "x86_64" ;;
        esac
    fi
}

# 从 GitHub Release 下载并安装二进制文件.
# 用法: install_from_github <命令名> <GitHub仓库> <资源关键词> [--raw | tar解压参数...]
install_from_github() {
    local cmd="$1"
    local repo="$2"
    local keyword="$3"
    shift 3
    # 旧版 fzf 可以运行, 但不一定提供 .bashrc 所需的 --bash 集成.
    local probe=--version
    if [[ "$cmd" == "fzf" ]]; then
        probe=--bash
    fi
    if "$cmd" "$probe" &>/dev/null; then
        info "✅ $cmd 已安装, 跳过."
        return
    fi

    info "🚀 正在安装 $cmd..."
    local url
    url=$(curl -fsSL "${PREFIX_PROXY}https://api.github.com/repos/${repo}/releases/latest" | \
        jq -r --arg keyword "$keyword" \
            '.assets | map(select(.name | test($keyword))) | first | .browser_download_url // empty')

    if [[ -z "$url" ]]; then
        error "无法为 ${repo} 找到匹配 \"${keyword}\" 的资源."
    fi

    local stage="$WORK_DIR/$cmd"
    mkdir -p "$stage"
    if [[ "${1:-}" == "--raw" ]]; then
        curl -fsSL "${PREFIX_PROXY}${url}" -o "$stage/$cmd"
    else
        curl -fsSL "${PREFIX_PROXY}${url}" -o "$WORK_DIR/$cmd.tar.gz"
        tar -xzf "$WORK_DIR/$cmd.tar.gz" -C "$stage" "$@"
    fi
    chmod +x "$stage"/*
    "$stage/$cmd" "$probe" >/dev/null || error "下载的 $cmd 无法运行, 请检查系统兼容性."
    mv -f "$stage"/* "$HOME/.local/bin/"
    info "✅ $cmd 安装成功."
}


# 主安装流程
info "📁 Dotfiles 仓库位于: $DOTFILES_DIR"
info "🚀 开始安装 dotfiles..."

# 1. 根据操作系统, 运行特定的安装脚本
case "$(uname -s)" in
    Darwin)
        # --- macOS 安装逻辑 ---
        info "🍎 检测到 macOS, 运行特定于 macOS 的安装脚本..."
        configure_network

        # 让当前进程也能找到已安装或即将安装的 Homebrew.
        if ! command -v brew &>/dev/null; then
            if [[ "$(uname -m)" == "arm64" ]]; then
                export PATH="/opt/homebrew/bin:$PATH"
            else
                export PATH="/usr/local/bin:$PATH"
            fi
        fi

        # 如果未安装 Homebrew, 则自动安装
        if ! command -v brew &>/dev/null; then
            info "🍺 未找到 Homebrew, 正在安装..."
            curl -fsSL "${PREFIX_PROXY}https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" -o "$WORK_DIR/homebrew-install.sh"
            /bin/bash "$WORK_DIR/homebrew-install.sh"
        else
            info "🍺 Homebrew 已安装, 跳过安装."
        fi
        eval "$(brew shellenv)"

        info "📦 正在通过 Brewfile 安装/更新软件包..."
        brew bundle --file=- <<-EOF
# 核心工具
brew "git"
brew "delta"
brew "rage"
brew "vim"
brew "coreutils"
brew "tig"
brew "jq"
brew "starship"
brew "htop"

# 推荐工具
brew "bat"     # 带语法高亮的 cat
brew "eza"     # ls 的现代替代品
brew "fzf"     # 命令行模糊搜索
brew "ripgrep" # 高性能 grep
brew "zoxide"  # 更智能的 cd
brew "universal-ctags" # ctags
brew "fastfetch"
brew "glow"    # Markdown 排版阅读
brew "yq"      # YAML 配置处理 (mikefarah/yq)
brew "dust"    # 目录空间占用
EOF
        if ! herdr --version &>/dev/null; then
            brew install herdr
        fi
        ;;

    Linux)
        # --- Linux 安装逻辑 ---
        info "🐧 检测到 Linux, 运行特定于 Linux 的安装脚本..."

        # 检测包管理器
        if command -v apt-get &>/dev/null; then
            info "📦 使用 apt 作为包管理器 (Debian/Ubuntu)."

            APT_PACKAGES=(
                "build-essential" "ca-certificates" "curl" "file" "git" "gzip" "jq" "rsync" "tar"
                "vim" "tig" "htop" "ripgrep" "zoxide" "universal-ctags"
            )

            # 给 github codespace 打个补丁
            if [ "${CODESPACES:-}" = "true" ] && [ -f /etc/apt/sources.list.d/yarn.list ]; then
                as_root sed -i '/^[[:space:]]*#/!s/^/# /' /etc/apt/sources.list.d/yarn.list
            fi

            as_root apt-get update -y
            info "🔧 正在安装依赖: ${APT_PACKAGES[*]}"
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"

            # Debian/Ubuntu 使用 glibc 版本的二进制
            linux_libc=gnu

        elif command -v dnf &>/dev/null; then
            # 使用 dnf (RHEL/Rocky/Alma 8+)
            info "📦 使用 dnf 作为包管理器 (RHEL/Rocky/Alma)."

            # 安装 EPEL 仓库
            info "📦 安装 EPEL 仓库..."
            as_root dnf install -y epel-release

            info "🔧 正在安装依赖..."
            as_root dnf groupinstall -y "Development Tools"
            as_root dnf install -y --allowerasing \
                ca-certificates curl file git gzip jq rsync tar \
                vim tig htop ripgrep ctags

            # RH 系列可能 glibc 版本较低, 使用 musl 版本的二进制更兼容
            linux_libc=musl

        else
            error "不支持的 Linux 包管理器, 请手动安装软件包."
        fi

        configure_network
        info "☁️ 正在从 GitHub Releases 安装缺失或不可用的二进制文件..."
        install_from_github "rage" "str4d/rage" "v[0-9.]*-$(get_arch_name rage)-linux.tar.gz$" --strip-components=1 --wildcards "*/rage" "*/rage-keygen"
        install_from_github "delta" "dandavison/delta" "$(get_arch_name)-unknown-linux-${linux_libc}.tar.gz$" --strip-components=1 --wildcards '*/delta'
        install_from_github "eza" "eza-community/eza" "eza.*$(get_arch_name)-unknown-linux-${linux_libc}.tar.gz$" "./eza"
        if [[ "$linux_libc" == "musl" ]]; then
            install_from_github "zoxide" "ajeetdsouza/zoxide" "$(get_arch_name)-unknown-linux-musl.tar.gz$" "zoxide"
        fi
        install_from_github "bat" "sharkdp/bat" "$(get_arch_name)-unknown-linux-musl.tar.gz$" --strip-components=1 --wildcards "*/bat"
        install_from_github "fzf" "junegunn/fzf" "linux_$(get_arch_name fzf).tar.gz$" "fzf"
        install_from_github "fastfetch" "fastfetch-cli/fastfetch" "fastfetch-linux-$(get_arch_name fastfetch).tar.gz$" --strip-components=3 "fastfetch-linux-$(get_arch_name fastfetch)/usr/bin/fastfetch"
        install_from_github "starship" "starship/starship" "starship-$(get_arch_name)-unknown-linux-musl.tar.gz$" "starship"
        install_from_github "herdr" "herdrdev/herdr" "^herdr-linux-$(get_arch_name)$" --raw
        install_from_github "glow" "charmbracelet/glow" "_Linux_$(get_arch_name glow).tar.gz$" --strip-components=1 --wildcards '*/glow'
        install_from_github "yq" "mikefarah/yq" "^yq_linux_$(get_arch_name yq)$" --raw
        install_from_github "dust" "bootandy/dust" "$(get_arch_name)-unknown-linux-musl.tar.gz$" --strip-components=1 --wildcards '*/dust'

        info "✅ Linux 特定软件包安装完成."
        ;;

    *)
        error "不支持的操作系统: $(uname -s)"
        ;;
esac

# 2. 创建配置文件链接
info "🔗 正在创建配置文件的链接..."

# 特殊处理: 向 ~/.bashrc 追加 source 命令
DOTFILES_BASHRC="${DOTFILES_DIR}/home/.bashrc"
SYSTEM_BASHRC="${HOME}/.bashrc"
SOURCE_CMD="source '${DOTFILES_BASHRC}'"

touch "${SYSTEM_BASHRC}"

if ! grep -qF "${SOURCE_CMD}" "${SYSTEM_BASHRC}"; then
    info "✒️ 正在向 ${SYSTEM_BASHRC} 添加 dotfiles loader..."
    printf "\n# 加载自定义 dotfiles\n%s\n" "${SOURCE_CMD}" >> "${SYSTEM_BASHRC}"
else
    info "✅ Dotfiles loader 已存在于 ${SYSTEM_BASHRC}, 跳过."
fi

info "🔗 正在链接 'home' 目录下的文件..."

# 需要链接的文件列表
files_to_link=(
    ".gitconfig"
    ".gitignore_global"
    ".editorconfig"
    ".tigrc"
    ".vimrc"
    ".config/htop/htoprc"
    ".config/fastfetch/config.jsonc"
    ".config/starship.toml"
)

for filename in "${files_to_link[@]}"; do
    src="${DOTFILES_DIR}/home/${filename}"
    dest="${HOME}/${filename}"

    mkdir -p "$(dirname "${dest}")"

    # 尝试创建硬链接, 如果失败则复制. -f 选项会覆盖已存在的目标文件.
    if ln -f "${src}" "${dest}" 2>/dev/null; then
        info "🔗 创建硬链接: ${dest}"
    else
        info "↗️ 硬链接失败, 转为复制文件: ${dest}"
        cp -fP "${src}" "${dest}"
    fi

done

# 3. 强制同步目录
info "⌛ 正在同步目录 (rsync)..."
dirs_to_sync=(
    ".vim/colors"
)

for dirname in "${dirs_to_sync[@]}"; do
    src="${DOTFILES_DIR}/home/${dirname}/"
    dest="${HOME}/${dirname}/"

    info "  同步中: ${src} -> ${dest}"
    mkdir -p "${dest}" && rsync -av --delete "${src}" "${dest}" >/dev/null
done


# 4. 有下载前缀时,为 Git 设置代理,加速 clone
if [[ -n "$PREFIX_PROXY" ]]; then
    info "🔧 正在为 Git 配置代理..."
    git config --global url."${PREFIX_PROXY}github.com/".insteadOf "https://github.com/"
fi

# 5. 安装 Vim 插件
info "🔌 正在安装 Vim 插件..."
if [ ! -s "${HOME}/.vim/autoload/plug.vim" ]; then
    info "  正在下载 vim-plug 插件管理器..."
    mkdir -p "${HOME}/.vim/autoload"
    curl -fsSL "${PREFIX_PROXY}https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" -o "$WORK_DIR/plug.vim"
    mv -f "$WORK_DIR/plug.vim" "${HOME}/.vim/autoload/plug.vim"
fi
info "  同步 Vim 插件并清理已删除的插件..."
# 保留普通模式, 避免 vim-plug 在 Ex 模式清理时出现 Invalid range.
if ! vim --not-a-term -u "${HOME}/.vimrc" \
    -c 'PlugUpdate --sync' -c 'PlugClean!' \
    -c 'if !empty(filter(values(g:plugs), "!isdirectory(v:val.dir)")) | cquit | endif' \
    -c 'qa' > "$WORK_DIR/vim.log" 2>&1; then
    cat "$WORK_DIR/vim.log" >&2
    error "Vim 插件同步失败, 请修复上述错误后重新运行."
fi

info "🎉 安装完成!"
info "💡 请重启您的 Shell, 或运行 'source ~/.bashrc' 来使配置生效."
