#!/bin/sh
# Codex 的非交互 Bash 入口; 普通 Shell 直接加载通用环境文件.
if [ -r "$HOME/.config/shell/env.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/shell/env.sh"
fi

# 子 Bash 继承已加载的变量, 保留调用方随后指定的临时覆盖.
export BASH_ENV=''
