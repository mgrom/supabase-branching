#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then set -a; source "$SCRIPT_DIR/.env"; set +a; fi

MOUNT="${BTRFS_MOUNT:-/mnt/pgdata}"
SIZE="${BTRFS_LOOPBACK_SIZE:-10G}"
IMG="${BTRFS_LOOPBACK_PATH:-/var/lib/supabase-branching/btrfs.img}"

usage() {
    echo "usage: $0 [--loopback | --device <dev>]"
    echo "  --loopback        create loopback btrfs volume ($SIZE)"
    echo "  --device <dev>    format block device as btrfs"
    echo "  --mount <path>    mount point (default: $MOUNT)"
    echo "  --size <size>     loopback size (default: $SIZE)"
    exit 1
}

setup_loopback() {
    mkdir -p "$(dirname "$IMG")"
    [ -f "$IMG" ] && { echo "error: $IMG exists, remove first"; exit 1; }
    echo "creating ${SIZE} loopback at $IMG"
    truncate -s "$SIZE" "$IMG"
    mkfs.btrfs "$IMG"
    mkdir -p "$MOUNT"
    mount -o loop "$IMG" "$MOUNT"
    echo "mounted at $MOUNT"
}

setup_device() {
    local dev="$1"
    [ ! -b "$dev" ] && { echo "error: $dev is not a block device"; exit 1; }
    echo "WARNING: formatting $dev as btrfs — all data will be lost"
    read -rp "continue? [y/N] " confirm
    [ "$confirm" = "y" ] || exit 1
    mkfs.btrfs -f "$dev"
    mkdir -p "$MOUNT"
    mount "$dev" "$MOUNT"
    echo "mounted at $MOUNT"
}

MODE=""; DEVICE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --loopback) MODE="loopback"; shift ;;
        --device) MODE="device"; DEVICE="$2"; shift 2 ;;
        --mount) MOUNT="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        *) usage ;;
    esac
done
[ -z "$MODE" ] && usage

case "$MODE" in
    loopback) setup_loopback ;;
    device) setup_device "$DEVICE" ;;
esac

echo ""
echo "btrfs ready at $MOUNT"
echo "fstab entry:"
[ "$MODE" = "loopback" ] && echo "  $IMG  $MOUNT  btrfs  loop  0  0" || echo "  $DEVICE  $MOUNT  btrfs  defaults  0  0"
