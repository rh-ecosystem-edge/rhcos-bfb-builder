# RHCOS BFB Build

This projects generates a Red Hat CoreOS (RHCOS) BFB image for the Nvidia BlueField DPU. It currently uses `custome-coreos-disk-images` to generate the live artifacts.

## Pre-requisites

### Container image build requirements

- Podman
- qemu-user-static-binfmt (needed for building on non-aarch64 machines)
- Active Red Hat subscription and the `subscription-manager` package.

### BFB build requirements

- Fedora aarch64 41 or later (Due to osbuild dependencies)
- skopeo
- SELinux disabled
- Disk Space - Ensure your Fedora system has at least 50GB of storage.

  `[ $(df --output=avail / | tail -1) -lt 52428800 ] && echo "Warning: Less than 50GB available"`

## Preparation

1. Ensure you are logged in to the Red Hat subscription manager

    ```bash
    sudo dnf install subscription-manager
    sudo subscription-manager register --username YOUR_USERNAME
    ```

2. Ensure dependencies are installed

    ```bash
    sudo dnf install -y podman skopeo git \
    osbuild osbuild-tools osbuild-ostree jq xfsprogs genisoimage
    ```

## Building the Image

1. The project contains Mellanox's bfscripts as a git submoudle, so be sure to clone it as well:

    ```bash
    git clone --recursive https://github.com/rh-ecosystem-edge/rhcos-bfb-builder.git
    ```

2. Obtain the OpenShift pull secret file and export it as an environment variable. you can obtain it from [Red Hat OpenShift Console](https://console.redhat.com/openshift/install/pull-secret).

    ```sh
    export PULL_SECRET=<path to pull secret file>
    ```

3. Get the RHCOS release images from OCP release payload, in this example we use 4.21.8

    ```bash
    export RHCOS_VERSION="4.21.8"
    export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")

    # driver-toolkit
    export BUILDER_IMAGE=$(oc adm release info --image-for driver-toolkit "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
    ```

4. Set NVIDIA DOCA stack versions

    Set Nvidia DPU stack versions:

    ```bash
    export DOCA_VERSION="3.2.1"
    export OFED_VERSION="25.10-1.7.1.0"
    export DOCA_DISTRO="rhel9.6"
    ```

5. Build the container image:

    ```bash
    podman build --squash -f rhcos-bfb.Containerfile \
      --authfile $PULL_SECRET \
      --build-arg RHCOS_VERSION=$RHCOS_VERSION \
      --build-arg TARGET_IMAGE=$TARGET_IMAGE \
      --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
      --build-arg D_DOCA_VERSION=$DOCA_VERSION \
      --build-arg D_OFED_VERSION=$OFED_VERSION \
      --build-arg D_DOCA_DISTRO=$DOCA_DISTRO \
      --tag "rhcos-bfb:$RHCOS_VERSION-latest" .
    ```

    Optionally, you can override the DOCA repository baseurl by adding: `-build-arg D_DOCA_BASEURL=<custom_doca_repo_baseurl>` to the above `podman build` command.

## Creating disk boot images

1. Export the container image into oci-archive format.

    ```bash
    skopeo copy containers-storage:localhost/rhcos-bfb:$RHCOS_VERSION-latest \
    oci-archive:rhcos-bfb_$RHCOS_VERSION.ociarchive
    ```

2. Execute [custom-coreos-disk-images](/custom-coreos-disk-images/README.md) to generate the live artifacts.

    ```bash
    # In the Fedora based system:
    sudo custom-coreos-disk-images/custom-coreos-disk-images.sh \
      --ociarchive rhcos-bfb_$RHCOS_VERSION.ociarchive \
      --platforms live \
      --metal-image-size 5000
    ```

## Creating a BFB image

Just execute the simple bash based BFB generation script.

```bash
./make_bfb.sh
```

## Booting the BFB on a BF3 DPU

```bash
bfb-install --rshim /dev/rshim0 --config worker.ign --bfb rhcos.bfb
```
