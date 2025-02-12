#!/bin/bash

echo
echo "==========================================" | tee /dev/kmsg
echo "Installing Red Hat CoreOS. Please wait... " | tee /dev/kmsg
echo "==========================================" | tee /dev/kmsg

IMG_INFO="$(stat /rhcos-bfb-metal.aarch64.raw.gz)"

echo " Image is: $IMG_INFO" | tee /dev/kmsg
if gzip -t /rhcos-bfb-metal.aarch64.raw.gz; then
  echo " Gzipped image is OK" | tee /dev/kmsg
else
  echo " Gzipped image is Corrupted" | tee /dev/kmsg
fi

#gzip -d /rhcos-bfb-metal.aarch64.raw.gz
IMG_INFO="$(stat /rhcos-bfb-metal.aarch64.raw.gz)"


modprobe -a nvme mmc_block 2>&1 | tee /dev/kmsg
# Todo: Add more modules if needed, especially for block devices.

default_device=/dev/mmcblk0
if [ -b /dev/nvme0n1 ]; then
	default_device="/dev/$(cd /sys/block; /bin/ls -1d nvme* | sort -n | tail -1)"
fi
device=${device:-"$default_device"}

echo "$(lsblk)"

sleep 5

gzip -cd /rhcos-bfb-metal.aarch64.raw.gz | dd of=$device bs=1M oflag=sync status=progress 2>&1 | tee /dev/kmsg
sync

#dd if=/rhcos-bfb-metal.aarch64.raw of=$device bs=64M oflag=sync status=progress 2>&1 | tee /dev/kmsg

if [ $? -eq 0 ]; then
        echo "========= DD write is done ========" | tee /dev/kmsg
        mount -t efivarfs none /sys/firmware/efi/efivars
        efibootmgr -c -d $device -p 2 -l '\EFI\redhat\grubaa64.efi' -L "Red-Hat CoreOS GRUB"

        echo "===================================" | tee /dev/kmsg
        echo "Installation finished. Rebooting..." | tee /dev/kmsg
        echo "===================================" | tee /dev/kmsg
	reboot -f
else
        echo "================================" | tee /dev/kmsg
        echo "Failed to install Red Hat CoreOS" | tee /dev/kmsg
        echo "================================" | tee /dev/kmsg
fi
