#!/bin/bash

default_device=/dev/mmcblk0
if [ -b /dev/nvme0n1 ]; then
  default_device="/dev/$(cd /sys/block; /bin/ls -1d nvme* | sort -n | tail -1)"
fi
device=${device:-"$default_device"}

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
    cat ${cfg_file} | tr -d '\0' > /tmp/bf.ign
    ls -lah $cfg_file | tee /dev/kmsg
  fi
  rm -f $cfg_file
fi

# multiline echo for the ignition file
if [ ! -f /tmp/bf.ign ]; then
  echo "INFO: Creating ignition file" | tee /dev/kmsg
  echo '{"ignition": {"version": "3.4.0"}}' > /tmp/bf.ign
fi


dd if=/dev/zero of=$device bs=1M count=1 status=progress

coreos-installer install $device \
  --append-karg "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 ignore_loglevel" \
  --ignition-file /tmp/bf.ign \
  --offline

sync

if efibootmgr -v | grep -q "Red-Hat CoreOS GRUB"; then
  efibootmgr -b $(efibootmgr -v | grep "Red-Hat CoreOS GRUB" | awk '{print $1}' | cut -d' ' -f1) -B
fi

efibootmgr -c -d $device -p 2 -l '\EFI\redhat\grubaa64.efi' -L "Red-Hat CoreOS GRUB"

reboot
