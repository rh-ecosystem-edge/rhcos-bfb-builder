# RHCOS BFB Build

### Pre-requisites
Podman and qemu-user-static are required to build the RHCOS image on a non-aarch64 machine.


### Build the RHCOS image
First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export RHCOS_CONTAINER=$(oc adm release info --image-for rhel-coreos quay.io/openshift-release-dev/ocp-release:4.17.9-aarch64)
```

Make sure you export PULL_SECRET, you can obtain it from console.redhat.com.
```bash
export PULL_SECRET=<path to pull secret file>
```

Now you can build the RHCOS image.
```bash
./build.sh

podman build --platform=linux/arm64 \
    --from $RHCOS_CONTAINER \
    --build-arg KERNEL=5.14.0-427.49.1.el9_4.aarch64 \
    --file Containerfile \
    --authfile $PULL_SECRET \
    --tag rhcos-bfb:latest .
```

### Creating disk boot images
```bash
skopeo copy containers-storage:rhcos-bfb:latest oci-archive:rhcos-bfb.ociarchive

git clone https://github.com/coreos/custom-coreos-disk-images.git
sudo custom-coreos-disk-images/custom-coreos-disk-images.sh --ociarchive rhcos-bfb.ociarchive --platforms metal
```
