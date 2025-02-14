#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm

[ -c /dev/null ] || mknod -m 666 /dev/null c 1 3
[ -c /dev/console ] || mknod -m 600 /dev/console c 5 1

export PATH=$PATH:/usr/sbin

echo "Loading kernel modules..."
modprobe i2c_mlxbf
modprobe virtio_console
modprobe mlxbf_tmfifo


modprobe act_skbedit
modprobe act_mirred
modprobe cls_matchall
modprobe act_gact
modprobe cls_flower
modprobe sch_ingress
modprobe rdma_ucm
modprobe nfnetlink_cttimeout
modprobe nfnetlink
modprobe rdma_cm
modprobe iw_cm
modprobe ib_ipoib
modprobe ib_cm
modprobe mst_pciconf
modprobe ipmb_host
modprobe ipmi_devintf
modprobe ipmi_msghandler
modprobe ipmb_dev_int
modprobe ib_umad
modprobe mlx5_ib
modprobe ib_uverbs
modprobe mlx5_fwctl
modprobe fwctl
modprobe sunrpc
modprobe mlx5_core
modprobe mlxdevm
modprobe ib_core
modprobe psample
modprobe mlxfw
modprobe pci_hyperv_intf
modprobe mmc_block
modprobe failover
modprobe sbsa_gwdt
modprobe nvme
modprobe nvme_core
modprobe mlx_compat
modprobe sdhci_of_dwcmshc
modprobe mlxbf_pmc
modprobe mmc_core
modprobe mlxbf_gige
modprobe vitesse
modprobe micrel
modprobe mlxbf_pka
modprobe pinctrl_mlxbf3
modprobe mlxbf_bootctl
modprobe i2c_mlxbf
modprobe pwr_mlxbf
modprobe xpmem
modprobe i2c_dev
modprobe nvme
modprobe mmc_block

sleep 10
echo "==========================================" | tee /dev/kmsg
echo "Loaded kernel modules.                    " | tee /dev/kmsg
echo "==========================================" | tee /dev/kmsg

sleep 5
echo "==========================================" | tee /dev/kmsg
echo "Installing Red Hat CoreOS. Please wait... " | tee /dev/kmsg
echo "==========================================" | tee /dev/kmsg

/usr/bin/install_rhcos.sh
