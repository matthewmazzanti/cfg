by_id="/dev/disk/by-id"
by_uuid="/dev/disk/by-uuid"
by_partuuid="/dev/disk/by-partuuid"
by_path="/dev/disk/by-path"
mapper="/dev/mapper"

get_password() {
    set +x
    local password confirm_password

    while true; do
        read -rsp "Enter password: " password
        echo
        read -rsp "Confirm password: " confirm_password
        echo

        if [[ -z "$password" ]]; then
            echo "Password cannot be empty." >&2
        elif [[ "$password" != "$confirm_password" ]]; then
            echo "Passwords do not match. Please try again." >&2
        else
            break
        fi
    done

    PASSWORD="$password"
    set -x
}
