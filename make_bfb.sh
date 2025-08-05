#!/bin/bash
set -ex

export PATH=$(realpath bfb/bfscripts):$PATH
export PROJDIR="$(realpath "$(dirname "$0")")"
WDIR=workspace
mkdir -p $WDIR
export WDIR=$(readlink -f $WDIR)

OUTDIR=$PROJDIR/output
mkdir -p $OUTDIR

IMG_NAME="rhcos-bfb"

kernel="$WDIR/kernel"
initramfs="$WDIR/initramfs"
initramfs_final="$WDIR/initramfs_final"

DATETIME=$(date +'%F_%H-%M-%S')

if [ -n "$RHCOS_VERSION" ]; then
    IMG_NAME="${IMG_NAME}_${RHCOS_VERSION}"
fi

if [ -n "$DOCA_VERSION" ]; then
    IMG_NAME="${IMG_NAME}_${DOCA_VERSION}"
fi

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
        --capsule "$WDIR/boot_update2.cap" \
        --boot-args-v0 "$boot_args" \
        --boot-args-v2 "$boot_args2" \
        --boot-path "$boot_path" \
        --boot-desc "$boot_desc" \
        --info "${WDIR}/info.json" \
        $WDIR/default.bfb $WDIR/${BFB_FILENAME}

    mv $WDIR/$BFB_FILENAME $OUTDIR/$BFB_FILENAME

    echo "$BFB_FILENAME BFB Image is Ready! $OUTDIR/$BFB_FILENAME"
    rm $boot_args
    rm $boot_args2
    rm $boot_path
    rm $boot_desc
}


main() {
    # default values to keep existing behavior
    coreos_kernel="${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-kernel.aarch64"
    coreos_initramfs="${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-initramfs.aarch64.img"
    coreos_rootfs="${PROJDIR}/rhcos-bfb_${RHCOS_VERSION}-live-rootfs.aarch64.img"

    # Call getopt to validate the provided input.
    options=$(getopt --options - --longoptions 'kernel:,initramfs:,rootfs:' -- "$@")
    if [ $? -ne 0 ]; then
        echo "Incorrect options provided"
        exit 1
    fi
    eval set -- "$options"
    while true; do
        case "$1" in
        --kernel)
            shift # The arg is next in position args
            coreos_kernel=$1
            ;;
        --initramfs)
            shift # The arg is next in position args
            coreos_initramfs=$1
            ;;
        --rootfs)
            shift # The arg is next in position args
            coreos_rootfs=$1
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
    cp "${coreos_kernel}" $kernel
    cat "${coreos_initramfs}" "${coreos_rootfs}" > $initramfs_final

    CID=$(podman run -d "rhcos-bfb:${RHCOS_VERSION}-latest" sleep infinity)

    podman cp $CID:/lib/firmware/mellanox/boot/default.bfb $WDIR/default.bfb
    podman cp $CID:/lib/firmware/mellanox/boot/capsule/boot_update2.cap $WDIR/boot_update2.cap
    podman cp $CID:/usr/opt/mellanox/bfb/info.json $WDIR/info.json

    podman stop $CID
    podman rm $CID

    buildbfb "${IMG_NAME}" $initramfs_final
}

main "$@"
