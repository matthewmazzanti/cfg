# Setup ls and tree to be a little nicer
# Handle homebrew coreutils preference
if command -v gdircolors &> /dev/null; then
    eval "$(gdircolors)"
    alias ls="gls --color=auto --group-directories-first --classify --dereference-command-line"
else
    eval "$(dircolors)"
    alias ls="ls --color=auto --group-directories-first --classify --dereference-command-line"
fi

alias tree="tree --dirsfirst"
