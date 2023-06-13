function mktar() { tar -czvf "$(basename $1).tar.gz" "$1" }
alias untar="tar -xzvf"
alias lstar="tar -tzvf"
