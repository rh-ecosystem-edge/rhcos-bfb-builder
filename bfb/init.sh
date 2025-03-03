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

MODULES="i2c_mlxbf virtio_console mlxbf_tmfifo \
act_skbedit act_mirred cls_matchall act_gact cls_flower sch_ingress rdma_ucm \
nfnetlink_cttimeout nfnetlink rdma_cm iw_cm ib_ipoib ib_cm mst_pciconf \
ipmb_host ipmi_devintf ipmi_msghandler ipmb_dev_int ib_umad mlx5_ib \
ib_uverbs mlx5_fwctl fwctl sunrpc mlx5_core mlxdevm ib_core psample mlxfw \
pci_hyperv_intf mmc_block failover sbsa_gwdt nvme nvme_core mlx_compat \
sdhci_of_dwcmshc mlxbf_pmc mmc_core mlxbf_gige vitesse micrel mlxbf_pka \
pinctrl_mlxbf3 mlxbf_bootctl i2c_mlxbf pwr_mlxbf xpmem i2c_dev nvme mmc_block"

echo "Loading kernel modules..."

for module in $MODULES; do
    modprobe "$module"
done

sleep 10
echo "==============================================" | tee /dev/kmsg
echo "  Loaded kernel modules.                      " | tee /dev/kmsg
echo "==============================================" | tee /dev/kmsg

/usr/bin/main.sh
