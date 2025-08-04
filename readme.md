# RHCOS BFB Build
This projects generates a Red Hat CoreOS (RHCOS) BFB image for the Nvidia BlueField DPU. It currently uses `custome-coreos-disk-images` to generate the live artifacts.

### Pre-requisites
Container image build requirements:
- Podman
- qemu-user-static-binfmt (needed for building on non-aarch64 machines)
- subscription-manager (Will enable podman to automount the subscription entitlements)
BFB build requirements:
- Fedora aarch64 41 or later (Due to osbuild dependencies)
- skopeo
- SELinux disabled


### Clone the project
The project contains Mellanox's bfscripts as a git submoudle, so be sure to clone it as well:
```bash
git clone --recursive https://github.com/rh-ecosystem-edge/rhcos-bfb-builder.git
```

### Build the RHCOS image
If you want to build RHCOS-BFB with drivers from source, you can follow the instructions [here](build-from-source.md).

First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export RHCOS_VERSION="4.20.0-ec.4"
export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
```

Make sure you export PULL_SECRET, you can obtain it from console.redhat.com.
```bash
export PULL_SECRET=<path to pull secret file>
```

Set Nvidia DPU stack versions:
```bash
export DOCA_VERSION="3.1.0-rhel9.6"
export DOCA_DISTRO=""
```

```bash
podman build -f rhcos-bfb.Containerfile \
--authfile $PULL_SECRET \
--build-arg D_ARCH=aarch64 \
--build-arg D_DOCA_VERSION=$DOCA_VERSION \
--build-arg D_FINAL_BASE_IMAGE=$TARGET_IMAGE \
--build-arg D_DOCA_DISTRO=$DOCA_DISTRO \
--tag "rhcos-bfb:$RHCOS_VERSION-latest"
```

### Creating disk boot images
```bash
skopeo copy containers-storage:localhost/rhcos-bfb:$RHCOS_VERSION-latest oci-archive:rhcos-bfb_$RHCOS_VERSION.ociarchive
```

You can follow the instructions at [custom-coreos-disk-images](/custom-coreos-disk-images/README.md) to generate the live artifacts.
```bash
# In Fedora based system:
sudo dnf install -y osbuild osbuild-tools osbuild-ostree podman jq xfsprogs
sudo custom-coreos-disk-images/custom-coreos-disk-images.sh \
  --ociarchive rhcos-bfb_$RHCOS_VERSION.ociarchive \
  --platforms live \
  --metal-image-size 5000
```

### Creating a BFB image
```bash
./make_bfb.sh
```

### Flashing to DPU
```bash
bfb-install --rshim /dev/rshim0 --config worker.ign --bfb rhcos.bfb
```
