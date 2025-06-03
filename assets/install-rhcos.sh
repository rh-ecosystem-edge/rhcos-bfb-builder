#!/bin/bash

IGNITION="/tmp/bf.ign"

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
    cat ${cfg_file} | tr -d '\0' > $IGNITION
    ls -lah $cfg_file | tee /dev/kmsg
  fi
  rm -f $cfg_file
fi

if [[ -f "$IGNITION" ]] && jq -e . "$IGNITION" >/dev/null 2>&1; then
  echo "INFO: Valid ignition file found – proceeding with installation." | tee /dev/kmsg

  coreos-installer install "$device" \
    --append-karg "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 ignore_loglevel" \
    --ignition-file "$IGNITION" \
    --offline

  sync

  if efibootmgr -v | grep -q "Red-Hat CoreOS GRUB"; then
    efibootmgr -b $(efibootmgr -v | grep "Red-Hat CoreOS GRUB" | awk '{print $1}' | cut -d' ' -f1) -B
  fi

  efibootmgr -c -d $device -p 2 -l '\EFI\redhat\grubaa64.efi' -L "Red-Hat CoreOS GRUB"

  reboot
else
  echo "INFO: Ignition file missing or invalid, skipping installation." | tee /dev/kmsg
  exit 1
fi
