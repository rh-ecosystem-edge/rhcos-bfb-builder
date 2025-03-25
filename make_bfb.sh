#!/bin/bash
set -e
export PROJDIR=$(realpath $(dirname $0))
WDIR=workspace
mkdir -p $WDIR
export WDIR=$(readlink -f $WDIR)

OUTDIR=$PROJDIR/output
mkdir -p $OUTDIR

kernel="$WDIR/kernel"
initramfs="$WDIR/initramfs"
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

    BFB="$bootimages/lib/firmware/mellanox/boot/default.bfb"
    CAPSULE="$bootimages/lib/firmware/mellanox/boot/capsule/boot_update2.cap"

    boot_args=$(mktemp)
    boot_args2=$(mktemp)
    boot_path=$(mktemp)
    boot_desc=$(mktemp)

    BFB_FILENAME="${ARG_NAME}_${DATETIME}.bfb"

    printf "console=ttyAMA1 console=hvc0 console=ttyAMA0 earlycon=pl011,0x01000000 earlycon=pl011,0x01800000 initrd=initramfs" > "$boot_args"
    printf "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 initrd=initramfs $KERNEL_DBG_ARGS" > "$boot_args2"

    printf "VenHw(F019E406-8C9C-11E5-8797-001ACA00BFC4)/Image" > "$boot_path"
    printf "Linux from rshim" > "$boot_desc"

    $PROJDIR/bfscripts/mlx-mkbfb \
        --image "$kernel" \
        --initramfs "$ARG_INITRAMFS" \
        --capsule "$CAPSULE" \
        --boot-args-v0 "$boot_args" \
        --boot-args-v2 "$boot_args2" \
        --boot-path "$boot_path" \
        --boot-desc "$boot_desc" \
        ${BFB} $WDIR/${BFB_FILENAME}

    mv $WDIR/$BFB_FILENAME $OUTDIR/$BFB_FILENAME

    echo "$BFB_FILENAME BFB Image is Ready! $OUTDIR/$BFB_FILENAME"
    rm $boot_args
    rm $boot_args2
    rm $boot_path
    rm $boot_desc
}


podman build -f installer.Containerfile --tag bfb-installer:latest

rm -rf $bootimages
echo "Extracting Mellanox BFB bootimages..."
mkdir -p $bootimages && rpm2cpio $bootimages_rpm | cpio -idm -D $bootimages

if command -v pigz &>/dev/null; then
    GZ="pigz"
else
    echo "pigz is not installing, will use gzip instead."
    GZ="gzip"
fi


echo "Building bfb/reboot.c..."
if [ "$(uname -m)" = "aarch64" ]; then
    gcc -o $PROJDIR/bfb/reboot $PROJDIR/bfb/reboot.c
else
    # aarch64-linux-gnu-gcc -o $PROJDIR/bfb/reboot $PROJDIR/bfb/reboot.c
    # TODO: create a cross-compile envrionment for aarch64
    echo "Error: Unsupported architecture!"
    exit 1
fi

if [ ! -f $PROJDIR/bfb/reboot ]; then
    echo "Error: bfb/reboot not found!"
    exit 1
fi


rm -rf $WDIR/initramfs_mod
mkdir $WDIR/initramfs_mod

echo "Extracting bfb-installer:latest to initramfs build directory..."
podman export $(podman create localhost/bfb-installer:latest) | tar -C $WDIR/initramfs_mod -xf -


rm -f $initramfs

zcat $WDIR/initramfs_mod/usr/lib/modules/*/vmlinuz > $kernel

# cp $WDIR/initramfs_mod/usr/lib/modules/*/initramfs.img $WDIR/initramfs.img
rm -rf $WDIR/initramfs_mod/usr/lib/modules/*/initramfs.img

pushd $WDIR/initramfs_mod

cp $PROJDIR/bfb/reboot usr/bin/reboot

cp $PROJDIR/bfb/init.sh init
cp $PROJDIR/bfb/shell.sh usr/bin/main.sh
chmod +x init
chmod +x usr/bin/main.sh

echo "Compressing debug initramfs using $GZ..."
find . | cpio -o -H newc | $GZ -c --fast > ${initramfs}_debug
popd
buildbfb debug ${initramfs}_debug

pushd $WDIR/initramfs_mod
cp $PROJDIR/bfb/install_rhcos.sh usr/bin/main.sh
chmod +x usr/bin/main.sh

echo "Compressing rhcos-bfb-metal.aarch64.raw using $GZ..."
$GZ -c -9 $PROJDIR/rhcos-bfb-metal.aarch64.raw > rhcos-bfb-metal.aarch64.raw.gz
split -b 1G -d rhcos-bfb-metal.aarch64.raw.gz rhcos-bfb-metal.aarch64.raw.gz.part-
rm -f rhcos-bfb-metal.aarch64.raw.gz

echo "Compressing initramfs using $GZ..."
find . | cpio -o -H newc | $GZ -c --fast > ${initramfs}_installer
# echo "Compressing initramfs back using zstd..."
# find . | cpio -o -H newc | zstd -c -1 > $initramfs
popd
buildbfb "${IMG_NAME}_installer" ${initramfs}_installer

rm -rf $WDIR/initramfs_mod
