#!/usr/bin/env bash
# 由交互式 Bash Shell 加载.

# 非交互式 Shell 直接退出.
case $- in
    *i*) ;;
      *) return;;
esac

# 定义仓库根目录.
export DOTFILES_DIR
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# 加载模块化脚本.
source "${DOTFILES_DIR}/lib/exports.sh"
source "${DOTFILES_DIR}/lib/path.sh"
source "${DOTFILES_DIR}/lib/aliases.sh"
source "${DOTFILES_DIR}/lib/functions.sh"

# 历史记录设置
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=30000
export HISTFILESIZE=20000
export HISTTIMEFORMAT="%F %T "
shopt -s histappend
if [[ ";${PROMPT_COMMAND:-};" != *';history -a;'* ]]; then
  PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

# 如果 starship 已安装, 则初始化.
if command -v starship &> /dev/null; then
  eval "$(starship init bash)"
fi

# 如果 zoxide 已安装, 则初始化.
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi

# 如果 fzf 已安装, 则初始化.
if command -v fzf &> /dev/null; then
  if command -v rg &> /dev/null; then
    export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND-rg --files --hidden --glob '!.git'}"
    export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND-$FZF_DEFAULT_COMMAND}"
  fi
  if command -v bat &> /dev/null && [[ -z "${FZF_CTRL_T_OPTS:-}" ]]; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range=:300 -- {}'"
  fi
  eval "$(fzf --bash)"
fi
