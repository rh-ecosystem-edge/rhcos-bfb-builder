# RHCOS BFB Build

### Pre-requisites
Podman and qemu-user-static are required to build the RHCOS image on a non-aarch64 machine.


### Build the RHCOS image
First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos quay.io/openshift-release-dev/ocp-release:4.13.12-aarch64)
export BUILDER_IMAGE=$(oc adm release info --image-for driver-toolkit quay.io/openshift-release-dev/ocp-release:4.13.12-aarch64)
```

Make sure you export PULL_SECRET, you can obtain it from console.redhat.com.
```bash
export PULL_SECRET=<path to pull secret file>
```

Now you can build the RHCOS image.
```bash
./build.sh
podman build --platform=linux/arm64 \
    --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
    --build-arg TARGET_IMAGE=$TARGET_IMAGE \
    --build-arg D_DOCA_VERSION=2.9.1 
    --file Containerfile \
    --authfile $PULL_SECRET \
    --tag rhcos-bfb:latest
```

### Creating disk boot images
```bash
skopeo copy containers-storage:rhcos-bfb:latest oci-archive:rhcos-bfb.ociarchive
git clone https://github.com/coreos/custom-coreos-disk-images.git
```

You can use `fedora:41` as it has the `osbuild-tools` package.
```bash
podman run --rm -it --privileged -v /root:/root fedora:41

# In the container
sudo dnf install -y osbuild osbuild-tools osbuild-ostree podman jq xfsprogs
sudo custom-coreos-disk-images/custom-coreos-disk-images.sh --ociarchive rhcos-bfb.ociarchive --platforms metal
```
