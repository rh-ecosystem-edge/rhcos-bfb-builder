#!/bin/bash

LOG="/tmp/rhcos-bfb_install.log"
IGNITION="/tmp/bf.ign"
rshimlog=$(which bfrshlog 2> /dev/null)

ln -s /usr/opt/* /opt

source /opt/mellanox/bfb/atf-uefi
source /opt/mellanox/bfb/bmc
source /opt/mellanox/bfb/nic-fw

rlog() {
    msg=$(echo "$*" | sed 's/INFO://;s/ERROR:/ERR/;s/WARNING:/WARN/')
    if [ -n "$rshimlog" ]; then
        $rshimlog "$msg"
    fi
}

ilog() {
    msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" >> $LOG
    echo "$msg" > /dev/kmsg
}

log() {
    ilog "$*"
    rlog "$*"
}

function_exists() {
	declare -f -F "$1" > /dev/null
	return $?
}

unmount_partition() {
    true
}

read_ignition_from_bootfifo() {
    local boot_fifo_path="/sys/bus/platform/devices/MLNXBF04:00/bootfifo"
    local cfg_file
    if [ -e "${boot_fifo_path}" ]; then
        cfg_file=$(mktemp)
        ilog "Trying to copy ignition..."
        dd if=${boot_fifo_path} of=${cfg_file} bs=4096 count=1000 > /dev/null 2>&1

        # Check the .xz signature {0xFD, '7', 'z', 'X', 'Z', 0x00} and extract the config file from it.
        local offset
        offset=$(strings -a -t d ${cfg_file} | grep -m 1 "7zXZ" | awk '{print $1}')
        
        if [ -s "${cfg_file}" -a ."${offset}" != ."1" ]; then
            ilog "INFO: Found file sized $(stat -c %s ${cfg_file}) bytes, extracting ignition config..."
            cat ${cfg_file} | tr -d '\0' > $IGNITION
        fi
        
        rm -f $cfg_file
    fi
}

install_rhcos() {
    default_device=/dev/mmcblk0
    if [ -b /dev/nvme0n1 ]; then
        default_device="/dev/$(cd /sys/block; /bin/ls -1d nvme* | sort -n | tail -1)"
    fi
    device=${device:-"$default_device"}

    if [[ -f "$IGNITION" ]]; then
        ilog "INFO: Ignition file found at $IGNITION"

        # Test if ignition is valid json using jq
        if ! jq -e . "$IGNITION" >/dev/null 2>&1; then
            ilog "ERROR: Ignition file is not a valid JSON."
            exit 1
        fi

        ilog "INFO: Installing Red Hat CoreOS on $device with ignition file $IGNITION"

        coreos-installer install "$device" \
            --append-karg "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 ignore_loglevel" \
            --ignition-file "$IGNITION" \
            --offline

        if [ $? -ne 0 ]; then
            ilog "ERROR: Failed to install Red Hat CoreOS."
            exit 1
        fi

        sync

        if efibootmgr -v | grep -q "Red-Hat CoreOS GRUB"; then
            efibootmgr -b $(efibootmgr -v | grep "Red-Hat CoreOS GRUB" | awk '{print $1}' | cut -d' ' -f1) -B
        fi

        efibootmgr -c -d $device -p 2 -l '\EFI\redhat\shimaa64.efi' -L "Red-Hat CoreOS GRUB"

    else
        ilog "INFO: Ignition file is missing, skipping installation."
        exit 1
    fi
}

# Firmware related identification
cx_pcidev=$(lspci -nD 2> /dev/null | grep 15b3:a2d[26c] | awk '{print $1}' | head -1)
cx_dev_id=$(lspci -nD -s ${cx_pcidev} 2> /dev/null | awk -F ':' '{print strtonum("0x" $NF)}')

read_ignition_from_bootfifo
install_rhcos

# bmc_components_update
update_atf_uefi
update_nic_firmware

ilog "INFO: Installation completed successfully, Rebooting in 5 Seconds..."
sleep 5
reboot



