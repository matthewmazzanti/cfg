#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

passfile="$(get_passfile)"
trap 'rm -f "$passfile"' EXIT INT TERM

KEY_DEV="$by_id/usb-USB_SanDisk_3.2Gen1_04019fcd9c4e79ca44691256512632c8626a90f14e01b7093716c05a775fdfdf29450000000000000000000015af046c00821b1883558107a8ac7d66-0:0"
KEY_FS="800e8fd9-22c6-4879-bbaf-99f506722cf9"

DEV="$by_id/nvme-Samsung_SSD_990_EVO_1TB_S7M3NL0X933009L_1"
ESP_PART="32527feb-6556-4559-9d7b-99f0a85bad8a"
ESP_FS="2413-6615"
SWAP_PART="58570ec6-bec4-4b1c-8dd6-4d037dddd15e"
SWAP_CRYPT="c5bbc38f-975a-46b0-af01-62b0c8b4b085"
ROOT_PART="c8662350-29ee-4ff2-b492-53be5b5e54c9"
ROOT_CRYPT="c74b3bec-0c38-4e8f-a2b0-bf89fa234b1a"
ROOT_FS="4b81dd49-4c1e-40ae-ba1f-0d2f5e5fd169"
BLOCK_SIZE="4096"

# Clean up $KEY_DEV
umount /key-dev || true
wipefs --all "$KEY_DEV" || true

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
    --new=2:0:+8G \
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

# Open and mount
cryptsetup open \
    --type=plain \
    --cipher=aes-xts-plain64 \
    --key-size=256 \
    --key-file=/dev/urandom \
    "$by_partuuid/$SWAP_PART" "$SWAP_CRYPT"

# Create Keyfile
mkfs.ext4 -L key -U "$KEY_FS" "$KEY_DEV"
mkdir -p /key-dev
wait_all_exist "$by_uuid/$KEY_FS"
mount -t ext4 -o noatime,nodiratime "$by_uuid/$KEY_FS" /key-dev
echo "hass" > /key-dev/system
chmod 400 /key-dev/system
touch /key-dev/key-file
chmod 400 /key-dev/key-file
head -c256 < /dev/urandom | base64 > /key-dev/key-file

# Create luks filesystem on root partition
cryptsetup luksFormat \
    --type=luks2 \
    --cipher=aes-xts-plain64 \
    --key-size=512 \
    --pbkdf=argon2id \
    --sector-size="$BLOCK_SIZE" \
    --uuid="$ROOT_CRYPT" \
    --key-file=/key-dev/key-file \
    "$by_partuuid/$ROOT_PART"

cryptsetup luksAddKey \
    --new-key-slot=31 \
    --new-keyfile="$passfile" \
    --key-file=/key-dev/key-file \
    "$by_partuuid/$ROOT_PART"

cryptsetup open \
    --persistent \
    --perf-no_read_workqueue \
    --perf-no_write_workqueue \
    --allow-discards \
    --key-file=/key-dev/key-file \
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
