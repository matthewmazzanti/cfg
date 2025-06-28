#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

passfile="$(get_passfile)"
trap 'rm -f "$passfile"' EXIT INT TERM

KEY_DEV="$by_id/usb-USB_SanDisk_3.2Gen1_010120f1fc6b4bb4ab4d7391d2fdf545bb3e6e6143450208f305b9fd806943b3e4e900000000000000000000f833a26f001c4900835581072a33742e-0:0"
KEY_FS="50c62c57-be39-4958-98fd-baab3d3b6d15"

DEV="$by_id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U5NJ0Y246737K_1"
ESP_PART="9576e63c-16e9-476c-a83e-3f49b539898d"
ESP_FS="CD23-F450"
SWAP_PART="000b890e-d62c-4678-a4a6-ea8f43b727a9"
SWAP_CRYPT="d7472648-6e61-409c-b7c9-903155901615"
ROOT_PART="dd27ca90-fa6b-4aa1-9e98-f1401e0e3dea"
ROOT_CRYPT="aa7f83ca-dfd0-47e1-981a-66740de64eb7"
ROOT_FS="3365f70d-8620-4d65-8612-11f34048ad37"
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
    --new=2:0:+16G \
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
    -O recordsize=32K \
    -O atime=off \
    -O xattr=sa \
    -O acltype=posixacl \
    -O mountpoint=none \
    root-pool "$mapper/$ROOT_CRYPT"

zfs create -o mountpoint=none root-pool/local
zfs create -o mountpoint=none root-pool/state
zfs create -o mountpoint=legacy root-pool/local/root
zfs create -o mountpoint=legacy -o recordsize=16K root-pool/local/nix
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
