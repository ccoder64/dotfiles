#!/usr/bin/env bash
# 通用 Shell 函数.

# 创建目录并立即进入.
# 用法: mkcd <目录名>
mkcd() {
    if [[ -z "${1-}" ]]; then
        echo "用法: mkcd <目录名>" >&2
        return 1
    fi
    mkdir -p -- "$1" && cd -- "$1" || return
}

# 搜索正文, 预览匹配行, 并在 Vim 中打开选中的位置.
# 用法: rgi <搜索表达式> [文件或目录...]
rgi() {
    if [[ $# -eq 0 ]]; then
        echo "用法: rgi <搜索表达式> [文件或目录...]" >&2
        return 1
    fi

    local pattern=$1 selected file line
    shift
    if [[ $# -eq 0 ]]; then
        set -- .
    fi

    selected=$(rg --line-number --with-filename --no-heading --color=never \
        --field-match-separator '\t' --smart-case -- "$pattern" "$@" | \
        fzf --delimiter '\t' \
            --preview 'bat --style=numbers --color=always --highlight-line {2} -- {1}' \
            --preview-window '+{2}-/2') || return

    IFS=$'\t' read -r file line _ <<< "$selected"
    vim "+$line" -- "$file"
}
