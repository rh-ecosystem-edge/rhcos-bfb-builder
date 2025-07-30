## Building RHCOS-BFB with drivers from source

### Build the RHCOS image
First use an openshift cluster to check the release image for the RHCOS version you want to build.
```bash
export RHCOS_VERSION="4.20.0-ec.4"

# Get RHCOS image
export TARGET_IMAGE=$(oc adm release info --image-for rhel-coreos "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
# Get driver toolkit image
export BUILDER_IMAGE=$(oc adm release info --image-for driver-toolkit "quay.io/openshift-release-dev/ocp-release:"$RHCOS_VERSION"-aarch64")
```

Set Nvidia DPU stack versions:
```bash
export OFED_VERSION="25.04-0.6.0.0"
export DOCA_VERSION="3.0.0"
export DOCA_DISTRO="rhel9.4"
```

```bash
podman build -f rhcos-bfb-source.Containerfile \
--authfile $PULL_SECRET \
--build-arg D_ARCH=aarch64 \
--build-arg D_DOCA_VERSION=$DOCA_VERSION \
--build-arg D_OFED_VERSION=$OFED_VERSION \
--build-arg D_BASE_IMAGE=$BUILDER_IMAGE \
--build-arg D_FINAL_BASE_IMAGE=$TARGET_IMAGE \
--build-arg D_DOCA_DISTRO=$DOCA_DISTRO \
--tag "rhcos-bfb:$RHCOS_VERSION-latest"
```
