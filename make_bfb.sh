#!/bin/bash
set -e
export PROJDIR=$(realpath $(dirname $0))
WDIR=workspace
mkdir -p $WDIR
export WDIR=$(readlink -f $WDIR)

vmlinuz="$WDIR/vmlinuz"
initramfs_def="$WDIR/initramfs_default"
initramfs="$WDIR/initramfs"
rhcos_rootfs="$WDIR/rhcos-live-rootfs.aarch64.img"
bootimages="$WDIR/bootimages"
bootimages_rpm="$WDIR/mlxbf-bootimages-signed-*.aarch64.rpm"

function download_rhcos_img() {
  local target_file="$1"
  local url="$2"

  if [[ -z "$target_file" || -z "$url" ]]; then
    echo "Usage: download_rhcos_img <target_file> <url>"
    return 1
  fi

  if [[ ! -f "$target_file" ]]; then
    echo "Downloading $target_file..."
    wget -O "$target_file" "$url" || { echo "Failed to download $target_file"; return 1; }
  else
    echo "$target_file already exists, skipping download."
  fi
}

function extract_squashfs_here() {
  local squashfs=$1
  local target=$2
  local target_dir=$(dirname "$target")

  local innerpaths=$(unsquashfs -l "$squashfs" | grep "$target")

  tempdir=$(mktemp -d)

  for file in $innerpaths; do
    file=${file#squashfs-root/}  # Ensure correct relative path
    unsquashfs -q -f -d "$tempdir" "$squashfs" "$file"

    dest="$target_dir/$(basename "$file")"
    \cp -fP "$tempdir/$file" "$dest"
  done

  \rm -rf "$tempdir"
}

download_rhcos_img "$vmlinuz" "https://mirror.openshift.com/pub/openshift-v4/arm64/dependencies/rhcos/4.17/latest/rhcos-live-kernel-aarch64"
download_rhcos_img "$initramfs_def" "https://mirror.openshift.com/pub/openshift-v4/arm64/dependencies/rhcos/4.17/latest/rhcos-live-initramfs.aarch64.img"
download_rhcos_img "$rhcos_rootfs" "https://mirror.openshift.com/pub/openshift-v4/arm64/dependencies/rhcos/4.17/latest/rhcos-live-rootfs.aarch64.img"

[ ! -f $bootimages_rpm ] && wget -r -np -e robots=off --reject-regex '(\?C=|index\.html)' -A "*.rpm" -nv -nd -P $WDIR https://linux.mellanox.com/public/repo/bluefield/latest/bootimages/prod/

rm -rf $bootimages
echo "Extracting Mellanox BFB bootimages..."
mkdir -p $bootimages && rpm2cpio $bootimages_rpm | cpio -idm -D $bootimages


####
kernel="$WDIR/kernel"
zcat $vmlinuz > $kernel
####

rm -rf $WDIR/rhcos_rootfs
mkdir $WDIR/rhcos_rootfs
echo "Decompressing RHCOS rootfs..."
zstdcat $rhcos_rootfs | cpio -idm -D $WDIR/rhcos_rootfs
ROOT_SQUASHFS=$(readlink -f $WDIR/rhcos_rootfs/root.squashfs)



rm -rf $WDIR/initramfs_mod
mkdir $WDIR/initramfs_mod
echo "Decompressing initramfs..."
zstdcat $initramfs_def | cpio -idm -D $WDIR/initramfs_mod
rm -f $initramfs

pushd $WDIR/initramfs_mod
echo "Editing RHCOS scripts in initramfs..."
rm -f etc/systemd/system/initrd-root-fs.target.requires/coreos-livepxe-rootfs.service
rm -f etc/systemd/system/ignition-diskful.target.requires/ignition-remount-sysroot.service
rm -rf etc/systemd/system/initrd-switch-root.target.requires
rm -rf etc/systemd/system/initrd-root-fs.target.wants
rm -rf etc/systemd/system/initrd-root-fs.target.requires
rm -f usr/lib/systemd/system/initrd-switch-root.service

extract_squashfs_here $ROOT_SQUASHFS usr/sbin/efibootmgr
extract_squashfs_here $ROOT_SQUASHFS lib64/libefivar.so.1
extract_squashfs_here $ROOT_SQUASHFS lib64/libefiboot.so.1

cp $PROJDIR/bfb/install-rhcos.service usr/lib/systemd/system/install-rhcos.service
cp $PROJDIR/bfb/rhcos-dpu.sh usr/bin/rhcos-dpu.sh
chmod +x usr/bin/rhcos-dpu.sh

ln -s /usr/lib/systemd/system/install-rhcos.service etc/systemd/system/initrd.target.wants/install-rhcos.service

echo "Compressing rhcos-bfb-metal.aarch64.raw using gzip..."
if command -v pigz &>/dev/null; then
    pigz -c --fast $PROJDIR/rhcos-bfb-metal.aarch64.raw > rhcos-bfb-metal.aarch64.raw.gz
else
    gzip -c --fast $PROJDIR/rhcos-bfb-metal.aarch64.raw > rhcos-bfb-metal.aarch64.raw.gz
fi

#echo "Copying rhcos-bfb-metal.aarch64.raw..."
#cp $PROJDIR/rhcos-bfb-metal.aarch64.raw rhcos-bfb-metal.aarch64.raw


echo "Compressing initramfs back using zstd..."
find . | cpio -o -H newc | zstd -c -5 --fast > $initramfs
popd
####

KERNEL_DBG_ARGS="ignore_loglevel"

BFB="$bootimages/lib/firmware/mellanox/boot/default.bfb"
CAPSULE="$bootimages/lib/firmware/mellanox/boot/capsule/boot_update2.cap"

DATETIME=$(date +'%F_%H-%M-%S')
BFB_FILENAME="rhcos-4.17_${DATETIME}.bfb"

boot_args=$(mktemp)
boot_args2=$(mktemp)
boot_path=$(mktemp)
boot_desc=$(mktemp)

printf "console=ttyAMA1 console=hvc0 console=ttyAMA0 earlycon=pl011,0x01000000 earlycon=pl011,0x01800000 initrd=initramfs modprobe.blacklist=mlx5_core" > "$boot_args"
printf "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 initrd=initramfs $KERNEL_DBG_ARGS modprobe.blacklist=mlx5_core" > "$boot_args2"

printf "VenHw(F019E406-8C9C-11E5-8797-001ACA00BFC4)/Image" > "$boot_path"
printf "Linux from rshim" > "$boot_desc"

$PROJDIR/bfscripts/mlx-mkbfb \
    --image "$kernel" --initramfs "$initramfs" \
    --capsule "$CAPSULE" \
    --boot-args-v0 "$boot_args" \
    --boot-args-v2 "$boot_args2" \
    --boot-path "$boot_path" \
    --boot-desc "$boot_desc" \
    ${BFB} workspace/${BFB_FILENAME}

echo $BFB_FILENAME
