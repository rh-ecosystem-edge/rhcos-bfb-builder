# RHCOS BFB Build

### Pre-requisites
Podman and qemu-user-static are required to build the RHCOS image on a non-aarch64 machine.


### Clone the project
The project contains Mellanox's bfscripts as a git submoudle, so be sure to clone it as well:
```bash
git clone --recursive https://github.com/Okoyl/rhcos-bfb.git
```

### Build the RHCOS image
First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export RHCOS_VERSION="4.17.12"
export KERNEL_VERSION="5.14.0-427.50.1.el9_4.aarch64"

export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
export BUILDER_IMAGE=$(oc adm release info --image-for driver-toolkit "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
```

Make sure you export PULL_SECRET, you can obtain it from console.redhat.com.
```bash
export PULL_SECRET=<path to pull secret file>
```

```bash
podman build -f rhcos-bfb.Containerfile \
--authfile $PULL_SECRET \
--build-arg D_OS=rhcos4.17 \
--build-arg D_ARCH=aarch64 \
--build-arg D_KERNEL_VER=$KERNEL_VERSION \
--build-arg D_OFED_VERSION=24.10-1.1.4.0 \
--build-arg D_BASE_IMAGE=$BUILDER_IMAGE \
--build-arg D_FINAL_BASE_IMAGE=$TARGET_IMAGE \
--build-arg D_DOCA_DISTRO=rhel9.2 \
--tag rhcos-bfb:latest
```

### Creating disk boot images
```bash
skopeo copy containers-storage:localhost/rhcos-bfb:latest oci-archive:rhcos-bfb.ociarchive
```

You can use `fedora:41` as it has the `osbuild-tools` package.
```bash
podman run --rm -it --privileged -v /root:/root fedora:41

# In Fedora based system:
sudo dnf install -y osbuild osbuild-tools osbuild-ostree podman jq xfsprogs
sudo custom-coreos-disk-images/custom-coreos-disk-images.sh \
  --ociarchive rhcos-bfb.ociarchive \
  --platforms metal \
  --metal-image-size 4500 \
  --extra-kargs "console=hvc0 console=ttyAMA0 earlycon=pl011,0x13010000 ignore_loglevel"
```

### Creating a BFB image
```bash
./make_bfb.sh
```

### Flashing to DPU
```bash
bfb-install --rshim /dev/rshim0 --config worker.ign --bfb rhcos.bfb
```
