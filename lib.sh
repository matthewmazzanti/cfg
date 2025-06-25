by_id="/dev/disk/by-id"
by_uuid="/dev/disk/by-uuid"
by_partuuid="/dev/disk/by-partuuid"
by_path="/dev/disk/by-path"
mapper="/dev/mapper"

get_password() {
    python3 - <<'EOF'
import sys
import getpass

password = getpass.getpass("Enter password: ")
confirm = getpass.getpass("Confirm password: ")

if password != confirm:
    print("Passwords do not match.", file=sys.stderr)
    sys.exit(1)

print(password, end="", flush=True)
EOF
}

get_passfile() {
    local passfile="$(mktemp)"
    chmod 600 "$passfile"
    get_password > "$passfile"
    echo "$passfile"
}

wipe_root_part() {
    local dev="$1"

    # Wipe all signatures on current partitions
    for part in "$dev"?*; do
        if [[ ! -e "$part" ]]; then
            continue
        fi
        wipefs --all "$part"
    done

    # Wipe all filesystem/RAID signatures on the device
    wipefs --all "$dev"

    # Clear the partition table
    sgdisk --zap-all "$dev"

    # Re-read the new partition table
    blockdev --rereadpt "$dev"

    # Wait for old partitions to get removed
    udevadm settle --timeout=10

    wait_none_exist "$dev"?*
}

MAX_TRIES=20
DELAY=0.5

wait_none_exist() {
    local try
    for try in $(seq 1 "$MAX_TRIES"); do
        if none_exist "$@"; then
            return 0
        fi
        sleep "$DELAY"
    done
    return 1
}

none_exist() {
    for file in "$@"; do
        if [[ -e "$file" ]]; then
            return 1
        fi
    done
    return 0
}

wait_all_exist() {
    local try
    for try in $(seq 1 "$MAX_TRIES"); do
        if all_exist "$@"; then
            return 0
        fi
        sleep "$DELAY"
    done
    return 1
}

all_exist() {
    for file in "$@"; do
        if [[ ! -e "$file" ]]; then
            return 1
        fi
    done
    return 0
}
