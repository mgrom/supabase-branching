#!/usr/bin/env bash
set -euo pipefail

MOUNT="/mnt/pgdata"
SIZE="10G"
IMG="/var/lib/supabase-branching/btrfs.img"

# TODO: add --device mode
# TODO: add argument parsing
echo "creating ${SIZE} loopback btrfs volume"

mkdir -p "$(dirname "$IMG")"
truncate -s "$SIZE" "$IMG"
mkfs.btrfs "$IMG"

mkdir -p "$MOUNT"
mount -o loop "$IMG" "$MOUNT"

echo "mounted btrfs at $MOUNT"
echo "add to fstab: $IMG  $MOUNT  btrfs  loop  0  0"
