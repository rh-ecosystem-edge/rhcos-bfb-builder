#!/bin/bash
set -ex

export PATH=$(realpath bfb/bfscripts):$PATH
export PROJDIR="$(realpath "$(dirname "$0")")"
WDIR=workspace
mkdir -p $WDIR
export WDIR=$(readlink -f $WDIR)

OUTDIR=$PROJDIR/output
mkdir -p $OUTDIR

IMAGE="$1"

source bfb/infojson.sh

kernel="$WDIR/kernel"
initramfs="$WDIR/initramfs"
initramfs_final="$WDIR/initramfs_final"
bootimages="$WDIR/bootimages"
bootimages_rpm="$WDIR/mlxbf-bootimages-signed-*.aarch64.rpm"

DATETIME=$(date +'%F_%H-%M-%S')

IMG_NAME="rhcos"

if [ -n "$RHCOS_VERSION" ]; then
    IMG_NAME="${IMG_NAME}_${RHCOS_VERSION}"
fi

[ ! -f $bootimages_rpm ] && wget -r -np -e robots=off --reject-regex '(\?C=|index\.html)' -A "*.rpm" -nv -nd -P $WDIR https://linux.mellanox.com/public/repo/bluefield/latest/bootimages/prod/


buildbfb() {
    ARG_NAME=$1
    ARG_INITRAMFS=$2

    KERNEL_DBG_ARGS="ignore_loglevel"

    boot_args=$(mktemp)
    boot_args2=$(mktemp)
    boot_path=$(mktemp)
    boot_desc=$(mktemp)

    BFB_FILENAME="${ARG_NAME}_${DATETIME}.bfb"

    printf "console=ttyAMA1 console=hvc0 console=ttyAMA0 earlycon=pl011,0x01000000 earlycon=pl011,0x01800000 initrd=initramfs" > "$boot_args"
    printf "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 initrd=initramfs systemd.wants=install-rhcos.service $KERNEL_DBG_ARGS" > "$boot_args2"

    printf "VenHw(F019E406-8C9C-11E5-8797-001ACA00BFC4)/Image" > "$boot_path"
    printf "Linux from rshim" > "$boot_desc"

    $PROJDIR/bfb/bfscripts/mlx-mkbfb \
        --image "$kernel" \
        --initramfs "$ARG_INITRAMFS" \
        --capsule "$CAPSULE" \
        --boot-args-v0 "$boot_args" \
        --boot-args-v2 "$boot_args2" \
        --boot-path "$boot_path" \
        --boot-desc "$boot_desc" \
        --info "${WDIR}/info.json" \
        ${BFB} $WDIR/${BFB_FILENAME}

    mv $WDIR/$BFB_FILENAME $OUTDIR/$BFB_FILENAME

    echo "$BFB_FILENAME BFB Image is Ready! $OUTDIR/$BFB_FILENAME"
    rm $boot_args
    rm $boot_args2
    rm $boot_path
    rm $boot_desc
}





rm -rf $bootimages
echo "Extracting Mellanox BFB bootimages..."
mkdir -p $bootimages && rpm2cpio $bootimages_rpm | cpio -idm -D $bootimages

if command -v pigz &>/dev/null; then
    GZ="pigz"
else
    echo "pigz is not installing, will use gzip instead."
    GZ="gzip"
fi

cp "${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-kernel.aarch64" $kernel

cat "${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-initramfs.aarch64.img" "${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-rootfs.aarch64.img" > $initramfs_final

BFB="$bootimages/lib/firmware/mellanox/boot/default.bfb"
CAPSULE="$bootimages/lib/firmware/mellanox/boot/capsule/boot_update2.cap"
ATF_UEFI_VERSION=$(rpm -q --queryformat '%{VERSION}' $bootimages_rpm)

build_infojson
buildbfb "${IMG_NAME}_coreos-installer" $initramfs_final
