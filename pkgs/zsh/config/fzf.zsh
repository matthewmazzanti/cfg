if ! command -v fzf fzf-share fd &> /dev/null; then
    return
fi

fd_opts=(
    "--hidden"
    "--ignore"
    "--no-follow"
    "--exclude" ".git/"
    "--strip-cwd-prefix"
)

export FZF_DEFAULT_OPTS="--reverse"
export FZF_DEFAULT_COMMAND="fd --type f $fd_opts"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# export FZF_CTRL_T_OPTS=""
export FZF_CTRL_R_OPTS="--reverse"
export FZF_ALT_C_COMMAND="fd --type d $fd_opts"
# export FZF_ALT_C_OPTS=""

source "$(fzf-share)/key-bindings.zsh"
