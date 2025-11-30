#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

DEV="$by_id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y211522R_1"
ESP_PART="3323c77b-40dd-4ce2-9fbb-1c86f4ffeffb"
ESP_FS="F0C3-BEFC"
SWAP_PART="2904eaf4-2c48-4a01-a63a-78b02b135c7e"
SWAP_CRYPT="c122f2eb-3662-4325-b61f-7d30f404df29"
ROOT_PART="628f1975-48cf-4d5b-bea2-e56bdb788994"
ROOT_CRYPT="8da62c32-7525-4ce6-a493-b4fc149e5421"
ROOT_FS="caf9898e-e681-4ef6-98f1-89f9515ce43d"
BLOCK_SIZE="4096"

confirm_rootfs SOURCE root-pool/local/root
confirm_reformat "$DEV"

passfile="$(get_passfile)"
trap 'rm -f "$passfile"' EXIT INT TERM

# Clean up $DEV
umount -R /mnt || true
swapoff "$mapper/$SWAP_CRYPT" || true
cryptsetup luksClose "$SWAP_CRYPT" || true
zpool destroy root-pool || true
cryptsetup luksClose "$ROOT_CRYPT" || true
wipe_root_part "$DEV"

# Create partition for primary disk
sgdisk \
    --set-alignment="$BLOCK_SIZE" \
    --align-end \
    --new=1:0:+10G \
    --typecode=1:EF00 \
    --change-name=1:ESP \
    --partition-guid=1:"$ESP_PART" \
    --new=2:0:+32G \
    --typecode=2:8200 \
    --change-name=2:swap \
    --partition-guid=2:"$SWAP_PART" \
    --new=3:0:0 \
    --typecode=3:8300 \
    --change-name=3:root \
    --partition-guid=3:"$ROOT_PART" \
    "$DEV"

blockdev --rereadpt "$DEV"
udevadm settle --timeout=10
wait_all_exist "$by_partuuid/$ESP_PART" "$by_partuuid/$ROOT_PART"

# Encrypted swap
cryptsetup open \
    --type=plain \
    --cipher=aes-xts-plain64 \
    --key-size=256 \
    --key-file=/dev/urandom \
    "$by_partuuid/$SWAP_PART" "$SWAP_CRYPT"

# Encrypt root filesystem
cryptsetup luksFormat \
    --type=luks2 \
    --cipher=aes-xts-plain64 \
    --key-size=512 \
    --pbkdf=argon2id \
    --batch-mode \
    --sector-size="$BLOCK_SIZE" \
    --uuid="$ROOT_CRYPT" \
    --key-file "$passfile" \
    "$by_partuuid/$ROOT_PART"

cryptsetup open \
    --persistent \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --allow-discards \
    --key-file "$passfile" \
    "$by_partuuid/$ROOT_PART" \
    "$ROOT_CRYPT"

# Create esp partition
mkfs.fat \
    -F 32 \
    -n ESP \
    -i "$(tr -d '-' <<<"$ESP_FS")" \
    "$by_partuuid/$ESP_PART"

# Create swap
mkswap --label=swap "$mapper/$SWAP_CRYPT"

# Create zfs/impermanence filesystems
zpool create -f \
    -o ashift="$(to_ashift "$BLOCK_SIZE")" \
    -O compression=lz4 \
    -O atime=off \
    -O xattr=sa \
    -O acltype=posixacl \
    -O mountpoint=none \
    root-pool "$mapper/$ROOT_CRYPT"

zfs create -o mountpoint=none root-pool/local
zfs create -o mountpoint=none root-pool/state
zfs create -o mountpoint=legacy root-pool/local/root
zfs create -o mountpoint=legacy root-pool/local/nix
zfs create -o mountpoint=legacy root-pool/state/persist
zfs create -o mountpoint=legacy root-pool/state/home
zfs snapshot root-pool/local/root@blank

# Mount all filesystems
swapon "$mapper/$SWAP_CRYPT"
mkdir -p /mnt
mount -t zfs -o noatime,nodiratime root-pool/local/root /mnt
mkdir -p /mnt/boot /mnt/nix /mnt/persist /mnt/home
mount -t vfat -o noatime,nodiratime "$by_uuid/$ESP_FS" /mnt/boot
mount -t zfs -o noatime,nodiratime root-pool/local/nix /mnt/nix
mount -t zfs -o noatime,nodiratime root-pool/state/persist /mnt/persist
mount -t zfs -o noatime,nodiratime root-pool/state/home /mnt/home
