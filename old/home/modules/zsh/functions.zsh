function mktar() {
    tar -czvf "$(basename $1).tar.gz" "$1"
}
