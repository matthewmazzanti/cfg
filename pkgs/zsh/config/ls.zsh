# Setup ls and tree to be a little nicer
eval "export $(dircolors | sed 's/01;/0;/g')"
alias ls="ls --color=auto --group-directories-first --classify --dereference-command-line"
alias tree="tree --dirsfirst"
