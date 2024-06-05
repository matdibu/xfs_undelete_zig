#!/bin/sh

set -e

DEVICE_IMG="$(realpath xfs_device.img)"
MOUNT_DIR="mount"
UNDELETED_DIR="recovered"

dd if=/dev/zero of="${DEVICE_IMG}" bs=4M count=128
mkfs.xfs "${DEVICE_IMG}" -f

mkdir -p "${MOUNT_DIR}"
MOUNT_DIR="$(realpath ${MOUNT_DIR})"

mkdir -p "${UNDELETED_DIR}"
UNDELETED_DIR="$(realpath ${UNDELETED_DIR})"

sudo mount "${DEVICE_IMG}" "${MOUNT_DIR}" -o user
sudo chown -R "$(id -un)":"$(id -gn)" "${MOUNT_DIR}"
python3 create_files.py
sudo umount -R "${MOUNT_DIR}"

sudo mount "${DEVICE_IMG}" "${MOUNT_DIR}" -o user
python3 delete_random.py
sudo umount -R "${MOUNT_DIR}"

rm -r "${MOUNT_DIR}"

zig build run -- --device "${DEVICE_IMG}" --output "${UNDELETED_DIR}"

# rm -f "${DEVICE_IMG}"

sudo chown -R "$(id -un)":"$(id -gn)" "${UNDELETED_DIR}"
