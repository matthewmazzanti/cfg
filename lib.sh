by_id="/dev/disk/by-id"
by_uuid="/dev/disk/by-uuid"
by_partuuid="/dev/disk/by-partuuid"
by_path="/dev/disk/by-path"
mapper="/dev/mapper"

confirm_rootfs() {
    local column="$1"
    local root="$2"
    if [[ "$(findmnt -n -o "$column")" == "$root" ]]; then
        echo "System currently mounted at root! Refusing to continue"
        exit 1
    fi
}

confirm_reformat() {
    echo "WARNING: This will reformat the following disks: $@"
    echo "ALL DATA WILL BE LOST"
    read -p "Type 'YES' to continue: " confirm
    if [[ "$confirm" != "YES" ]]; then
        echo "Aborted"
        exit 1
    fi
}

get_password() {
    python3 - <<'EOF'
import sys
import getpass

while True:
    password = getpass.getpass("Enter password: ")
    confirm = getpass.getpass("Confirm password: ")
    if password == confirm:
        break
    print("Passwords do not match, try again", file=sys.stderr)

print(password, end="", flush=True)
EOF
}

get_passfile() {
    local passfile="$(mktemp)"
    chmod 600 "$passfile"
    get_password > "$passfile"
    echo "$passfile"
}

to_ashift() {
    local block_size="$1"
    python3 - "$block_size" <<'EOF'
import math
import sys
block_size = int(sys.argv[1])
ashift = int(math.log2(block_size))
print(ashift)
EOF
}

install_user_password() {
    user="$1"
    mkdir -p /mnt/persist/passwd
    touch "/mnt/persist/passwd/$user"
    chown root:shadow "/mnt/persist/passwd/$user"
    chmod 640 "/mnt/persist/passwd/$user"

    echo "Creating password for $1"
    get_password | openssl passwd -6 -stdin > "/mnt/persist/passwd/$user"
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
