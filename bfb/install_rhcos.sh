#!/bin/bash
set -e

sleep 5
echo "==============================================" | tee /dev/kmsg
echo "  Installing Red Hat CoreOS. Please wait...   " | tee /dev/kmsg
echo "==============================================" | tee /dev/kmsg


default_device=/dev/mmcblk0
if [ -b /dev/nvme0n1 ]; then
  default_device="/dev/$(cd /sys/block; /bin/ls -1d nvme* | sort -n | tail -1)"
fi
device=${device:-"$default_device"}

echo "Target device is $device" | tee /dev/kmsg

boot_fifo_path="/sys/bus/platform/devices/MLNXBF04:00/bootfifo"
if [ -e "${boot_fifo_path}" ]; then
  cfg_file=$(mktemp)
  # Get 4MB assuming it's big enough to hold the config file.
  echo "Trying to copy ignition..." | tee /dev/kmsg
  dd if=${boot_fifo_path} of=${cfg_file} bs=4096 count=1000 > /dev/null 2>&1

  ls -lah $cfg_file | tee /dev/kmsg

  #
  # Check the .xz signature {0xFD, '7', 'z', 'X', 'Z', 0x00} and extract the
  # config file from it. Then start decompression in the background.
  #
  offset=$(strings -a -t d ${cfg_file} | grep -m 1 "7zXZ" | awk '{print $1}')
  if [ -s "${cfg_file}" -a ."${offset}" != ."1" ]; then
    echo "INFO: Found text" | tee /dev/kmsg
    cat ${cfg_file} | tr -d '\0' > /tmp/bf.cfg
    ls -lah $cfg_file | tee /dev/kmsg
  fi
  rm -f $cfg_file
fi

if [ ! -f /tmp/bf.cfg ]; then
  echo "Error! Ignition not provided via bfb-install. Not installing" | tee /dev/kmsg
  exec /bin/bash
fi

cat $(ls /rhcos-bfb-metal.aarch64.raw.gz.part-* | sort -V) | gzip -cd - | dd of=$device bs=1M oflag=sync status=progress 2>&1 | tee /dev/kmsg
# gzip -cd /rhcos-bfb-metal.aarch64.raw.gz | dd of=$device bs=1M oflag=sync status=progress 2>&1 | tee /dev/kmsg
sync

echo "Finished writing Image to $device..." | tee /dev/kmsg

mount -t efivarfs none /sys/firmware/efi/efivars
efibootmgr -c -d $device -p 2 -l '\EFI\redhat\grubaa64.efi' -L "Red-Hat CoreOS GRUB"
echo "Written EFI record." | tee /dev/kmsg

if [ -f /tmp/bf.cfg ]; then
modprobe ext4
sleep 1

mount "${device}p3" /mnt
mkdir /mnt/ignition
cp /tmp/bf.cfg /mnt/ignition/config.ign
umount /mnt
fi

echo "Copied ignition to boot partition." | tee /dev/kmsg

echo "===================================" | tee /dev/kmsg
echo "  Installation finished.           " | tee /dev/kmsg
echo "  Rebooting in 1 seconds...        " | tee /dev/kmsg
echo "===================================" | tee /dev/kmsg

sleep 1

/usr/bin/reboot

# while true; do
#     echo "rebooting" | tee /dev/kmsg
#     echo s > /proc/sysrq-trigger
#     echo u > /proc/sysrq-trigger
#     echo b > /proc/sysrq-trigger
#     sleep 1
# done
