#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e 

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}

if [ "`uname -m`" == "ppc64le" ]; then
  # ppc64le guest images have a PReP partition 
  # this and other code changes for ppc64le with input from Paulo Flabiano Smorigo @ IBM
  part_offset=2048s
  part_size=9MiB
else
  # Reserve the first 63 sectors for grub
  part_offset=63s
  part_size=$((${image_create_disk_size} - 1))
fi

dd if=/dev/null of=${disk_image} bs=1M seek=${image_create_disk_size} 2> /dev/null
parted --script ${disk_image} mklabel msdos
if [ "`uname -m`" == "ppc64le" ]; then
  parted --script ${disk_image} mkpart primary $part_offset $part_size
  parted --script ${disk_image} set 1 boot on
  parted --script ${disk_image} set 1 prep on
  parted --script ${disk_image} mkpart primary ext4 $part_size 100%
else
  parted --script ${disk_image} mkpart primary ext2 $part_offset $part_size
fi
echo "ilsiyar"
echo ${disk_image}
 
# unmap the loop device in case it's already mapped
kpartx -dv ${disk_image}

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
echo device

if [ "`uname -m`" == "ppc64le" ]; then
  #device_partition=$(kpartx -av ${device} | grep "^add" | grep "p2 "| cut -d" " -f3)
  device_partition=$(kpartx -av ${device} | grep "^add" | grep "p2 " | grep -v "p1" | cut -d" " -f3)
else
  device_partition=$(kpartx -av ${device} | grep "^add" | cut -d" " -f3)
fi
loopback_dev="/dev/mapper/${device_partition}"

# Format partition
mkfs.ext4 ${loopback_dev}

# Mount partition
image_mount_point=${work}/mnt
mkdir -p ${image_mount_point}
mount ${loopback_dev} ${image_mount_point}

# Copy root
time rsync -aHA $chroot/ ${image_mount_point}

# Unmount partition
for try in $(seq 0 9); do
  sleep $try
  echo "Unmounting ${image_mount_point} (try: ${try})"
  umount ${image_mount_point} || continue
  break
done

if mountpoint -q ${image_mount_point}; then
  echo "Could not unmount ${image_mount_point} after 10 tries"
  exit 1
fi

# Unmap partition
for try in $(seq 0 9); do
  sleep $try
  echo "Removing device mappings for ${disk_image} (try: ${try})"
  kpartx -dv ${device} && losetup --verbose --detach ${device} || continue
  break
done

if [ -b ${loopback_dev} ]; then
  echo "Could not remove device mapping at ${loopback_dev}"
  exit 1
fi
