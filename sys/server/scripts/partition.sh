#!/usr/bin/env bash
set -xeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../lib.sh"

KEY_DEV="$by_id/usb-USB_SanDisk_3.2Gen1_01017529487ef0c9a1ba96ca2d7456553b31c2036f1da2f1b6eb04fe662b0413d8e40000000000000000000084629741001e5a00835581072a336cdf-0:0"
KEY_FS="f893b93f-b2a7-4de9-9650-71e6d850102d"

DEV="$by_id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0Y211600L_1"
ESP_PART="58aceda6-ed23-4100-8127-ff4092da9de1"
ESP_FS="D01B-0C25"
SWAP_PART="19010be8-1da1-4dd9-bf8d-12cfdffe39f6"
SWAP_CRYPT="bd9314f2-1074-428d-a1ed-7ab0d5fd36fe"
ROOT_PART="6a97241c-c862-49d7-9d8d-c20a63f96024"
ROOT_CRYPT="5934f569-b4a3-492e-9c5c-6429939a4082"
ROOT_FS="5bf2dcbd-3bb5-47c4-86c8-bba504f7688e"
BLOCK_SIZE="4096"

DATA_DEVS=(
  "$by_id/ata-WDC_WD260KFGX-68CNGN0_SZG5VDTM"
  "$by_id/ata-WDC_WD260KFGX-68CNGN0_SZGU4X6N"
  "$by_id/ata-WDC_WD260KFGX-68CNGN0_SZGU7T0N"
  "$by_id/ata-WDC_WD260KFGX-68CNGN0_SZG4ZYHM"
)
DATA_CRYPTS=(
  "e0c6ed81-51f8-423c-ba9f-2873837a91e7"
  "b2bcfa53-8f2e-47b2-b7d7-3a68f2a13660"
  "26713afa-4b9b-41b3-be58-8ae760a31ca9"
  "61a8a2ef-77e7-41bd-9448-8e4404a040e6"
)

confirm_rootfs SOURCE root-pool/local/root
confirm_reformat "$DEV" "$KEY_DEV"

passfile="$(get_passfile)"
trap 'rm -f "$passfile"' EXIT INT TERM

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

# Clean up $DATA_DEVS
zpool destroy data-pool || true
for i in "${!DATA_DEVS[@]}"; do
    cryptsetup luksClose "${DATA_CRYPTS[i]}" || true
    wipefs --all "${DATA_DEVS[i]}" || true
done

# Create partition for primary disk
sgdisk \
    --set-alignment="$BLOCK_SIZE" \
    --align-end \
    --new=1:0:+10G \
    --typecode=1:EF00 \
    --change-name=1:ESP \
    --partition-guid=1:"$ESP_PART" \
    --new=2:0:+48G \
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
    --batch-mode \
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

for i in "${!DATA_DEVS[@]}"; do
    cryptsetup luksFormat \
        --type=luks2 \
        --cipher=aes-xts-plain64 \
        --key-size=512 \
        --pbkdf=argon2id \
        --batch-mode \
        --sector-size="$BLOCK_SIZE" \
        --uuid="${DATA_CRYPTS[i]}" \
        --key-file=/key-dev/key-file \
        "${DATA_DEVS[i]}"

    cryptsetup luksAddKey \
        --new-key-slot=31 \
        --new-keyfile="$passfile" \
        --key-file=/key-dev/key-file \
        "${DATA_DEVS[i]}"

    cryptsetup open \
        --persistent \
        --perf-no_read_workqueue \
        --perf-no_write_workqueue \
        --key-file=/key-dev/key-file \
        "${DATA_DEVS[i]}" \
        "${DATA_CRYPTS[i]}"
done

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

# Create data-pool
zpool create -f \
    -o ashift="$(to_ashift "$BLOCK_SIZE")" \
    -O compression=lz4 \
    -O atime=off \
    -O xattr=sa \
    -O acltype=posixacl \
    -O mountpoint=none \
    data-pool raidz1 "${DATA_CRYPTS[@]/#/$mapper/}"


# -- Impermanence --
zfs create -o mountpoint=none root-pool/local
zfs create -o mountpoint=legacy root-pool/local/root
zfs create -o mountpoint=legacy root-pool/local/nix
zfs snapshot root-pool/local/root@blank

# -- Persistence --
zfs create -o mountpoint=none root-pool/state
zfs create -o mountpoint=legacy root-pool/state/persist
zfs create -o mountpoint=legacy root-pool/state/home

# -- General File Server --
zfs create -o mountpoint=none data-pool/share
zfs create -o mountpoint=legacy data-pool/share/media
zfs create -o mountpoint=legacy data-pool/share/documents

# Mount all filesystems
swapon "$mapper/$SWAP_CRYPT"
mkdir -p /mnt
mount -t zfs -o noatime,nodiratime root-pool/local/root /mnt

mkdir -p /mnt/boot /mnt/nix /mnt/persist /mnt/home
mount -t vfat -o noatime,nodiratime "$by_uuid/$ESP_FS"       /mnt/boot
mount -t zfs  -o noatime,nodiratime root-pool/local/nix      /mnt/nix
mount -t zfs  -o noatime,nodiratime root-pool/state/persist  /mnt/persist
mount -t zfs  -o noatime,nodiratime root-pool/state/home     /mnt/home

mkdir -p /mnt/srv/gitea /mnt/srv/share/media /mnt/srv/share/documents /mnt/srv/backups/mbp
mount -t zfs -o noatime,nodiratime data-pool/share/media      /mnt/srv/share/media
mount -t zfs -o noatime,nodiratime data-pool/share/documents  /mnt/srv/share/documents
