#!/usr/bin/env sh

set -e

DEVICE_IMG="$(realpath xfs_device.img)"
MOUNT_DIR="mount"
UNDELETED_DIR="recovered"
FILE_COUNT="4000" # create N files
DELETE_RATIO="2" # delete one in N files

dd if=/dev/zero of="${DEVICE_IMG}" bs=4M count=256
mkfs.xfs "${DEVICE_IMG}" -f

mkdir -p "${MOUNT_DIR}"
MOUNT_DIR=$(realpath "${MOUNT_DIR}")

mkdir -p "${UNDELETED_DIR}"
UNDELETED_DIR=$(realpath "${UNDELETED_DIR}")

sudo mount "${DEVICE_IMG}" "${MOUNT_DIR}" -o user
user=$(id -un)
group=$(id -gn)
sudo chown -R "${user}":"${group}" "${MOUNT_DIR}"
python3 create_files.py "${FILE_COUNT}"
sudo umount -R "${MOUNT_DIR}"

sudo mount "${DEVICE_IMG}" "${MOUNT_DIR}" -o user
python3 delete_random.py "${DELETE_RATIO}"
sudo umount -R "${MOUNT_DIR}"

rm -r "${MOUNT_DIR}"

zig build run -- --device "${DEVICE_IMG}" --output "${UNDELETED_DIR}"

# rm -f "${DEVICE_IMG}"

sudo chown -R "${user}":"${group}" "${UNDELETED_DIR}"
