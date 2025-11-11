ARG BUILDER_IMAGE
ARG TARGET_IMAGE
ARG RHCOS_VERSION
ARG D_ARCH
ARG D_CONTAINER_VER=0
ARG D_DOCA_VERSION
ARG D_DOCA_BASEURL=https://linux.mellanox.com/public/repo/doca

FROM ${TARGET_IMAGE} AS base

ARG RHCOS_VERSION
ARG D_DOCA_VERSION
ARG D_DOCA_DISTRO
ARG D_DOCA_BASEURL=
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR
ARG IMAGE_TAG
ARG COREOS_OPENCONTAINERS_IMAGE_VERSION

ENV D_DOCA_FINALURL=${D_DOCA_BASEURL:-https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/${D_DOCA_DISTRO}/arm64-dpu/}

RUN dnf config-manager --set-enabled codeready-builder-for-rhel-9-$(uname -m)-rpms || \
  dnf config-manager --set-enabled codeready-builder-beta-for-rhel-9-$(uname -m)-rpms; \
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm; \
  # EPEL is required for jsoncpp strongswan libunwind
  dnf clean all; \
  mkdir -p /tmp/rpms; \
  cat <<EOF > /etc/yum.repos.d/doca.repo
[doca]
name=Nvidia DOCA repository
baseurl=${D_DOCA_FINALURL}
gpgcheck=0
enabled=1
EOF

WORKDIR /

RUN \
  # Setup /opt for package installations
  rm opt && mkdir -p usr/opt && ln -s usr/opt opt; \
  #
  # Remove default packages
  dnf remove -y \
  # Replace openvswitch with doca-openvswitch
  openvswitch-selinux-extra-policy openvswitch* \
  # Remove unused big packages
  geolite2-city \
  ose-azure-acr-image-credential-provider \
  ose-aws-ecr-image-credential-provider \
  ose-gcp-gcr-image-credential-provider; \
  #
  # # Install doca-runtime meta packages without their dependencies
  #cd /tmp; \
  # dnf download doca-runtime doca-runtime-kernel doca-runtime-user bf-release && \
  # rpm -ivh --nodeps \
  # doca-runtime-kernel-${D_DOCA_VERSION}*.${D_ARCH}.rpm \
  # doca-runtime-user*.${D_ARCH}.rpm \
  # doca-runtime-${D_DOCA_VERSION}*.${D_ARCH}.rpm; \
  ## doca-runtime-kernel and doca-devel-kernel are still tied to specific kernel, but we compiled these on our own, so we ignore the specific version dependency
  ## doca-runtime-user requires it's own doca-openvswitch packages, and requires bf-release
  #
  # Install bf-release in a hacky way until we have a proper bf-release package
  cd /tmp; \
  dnf download bf-release && \
  mkdir /tmp/bf-release && \
  rpm --notriggers --replacefiles --justdb -ivh --nodeps bf-release-*.aarch64.rpm && \
  rpm2cpio bf-release-*.aarch64.rpm | cpio -idm -D /tmp/bf-release; \
  rm -rf /tmp/bf-release/var /tmp/bf-release/usr/lib/systemd /tmp/bf-release/usr/share /tmp/bf-release/etc/sysconfig \
  /tmp/bf-release/etc/NetworkManager \
  /tmp/bf-release/etc/crictl* /tmp/bf-release/etc/kubelet.d /tmp/bf-release/etc/cni; \
  cp -rnv /tmp/bf-release/* /; \
  echo "bf-bundle-${D_DOCA_VERSION}_rhcos${RHCOS_VERSION}" > /etc/mlnx-release; \
  #
  dnf clean all

RUN dnf -y install --setopt=install_weak_deps=False \
  doca-runtime \
  collectx-clxapi \
  doca-apsh-config \
  doca-bench \
  doca-caps \
  doca-comm-channel-admin \
  doca-flow-tune \
  doca-openvswitch \
  doca-openvswitch-ipsec \
  doca-openvswitch-selinux-policy \
  doca-openvswitch-test \
  doca-pcc-counters \
  doca-sdk-aes-gcm \
  doca-sdk-apsh \
  doca-sdk-argp \
  doca-sdk-comch \
  doca-sdk-common \
  doca-sdk-compress \
  doca-sdk-devemu \
  doca-sdk-dma \
  doca-sdk-dpa \
  doca-sdk-dpdk-bridge \
  doca-sdk-erasure-coding \
  doca-sdk-eth \
  doca-sdk-flow \
  doca-sdk-pcc \
  doca-sdk-rdma \
  doca-sdk-sha \
  doca-sdk-telemetry \
  doca-sdk-telemetry-exporter \
  doca-sdk-urom \
  doca-socket-relay \
  doca-sosreport \
  dpa-stats \
  dpcp  \
  flexio-sdk \
  ibacm \
  infiniband-diags \
  infiniband-diags-compat \
  libibumad \
  libibverbs \
  libibverbs-utils \
  libpka \
  libpka-engine \
  libpka-testutils \
  librdmacm \
  librdmacm-utils \
  libvma \
  libvma-utils \
  mft \
  mft-oem \
  mlnx-dpdk \
  mlnx-ethtool \
  mlnx-iproute2 \
  mlx-OpenIPMI \
  mlxbf-bfscripts \
  mlxbf-bootimages-signed \
  mlnx-fw-updater-signed \
  ofed-scripts \
  opensm \
  opensm-libs \
  opensm-static \
  perftest \
  rdma-core \
  srp_daemon \
  ucx \
  ucx-cma \
  ucx-ib \
  ucx-knem \
  ucx-rdmacm \
  ucx-xpmem \
  acpid \
  mstflint \
  mft-autocomplete \
  mmc-utils \
  device-mapper \
  lm_sensors \
  efibootmgr \
  i2c-tools \ 
  ipmitool \ 
  nvmetcli\
  bf3-bmc-fw-signed bf3-bmc-gi-signed bf3-bmc-nic-fw* \
  bf3-cec-fw-signed \
  vim-common \
  dhcp-client \
  && dnf clean all && \
  rpm -e --nodeps libnl3-devel kernel-headers libzstd-devel ncurses-devel libpcap-devel \
  elfutils-libelf-devel meson libyaml-devel ninja-build epel-release

COPY assets/doca-ovs_sfc.te /tmp/sfc_controller.te

COPY assets/install-rhcos.sh /usr/bin/install-rhcos.sh
COPY assets/install-rhcos.service /usr/lib/systemd/system/install-rhcos.service

RUN \
  # Copy OFED udev rules
  cp /usr/share/doc/mlnx-ofa_kernel/vf-net-link-name.sh /etc/infiniband/vf-net-link-name.sh && \
  cp /usr/share/doc/mlnx-ofa_kernel/82-net-setup-link.rules /usr/lib/udev/rules.d/82-net-setup-link.rules && \
  #
  # Patch installed packages
  sed -i 's/\/run\/log/\/var\/log/i' /usr/bin/mlx_ipmid_init.sh && \
  sed -i 's/\/run\/log/\/var\/log/i' /usr/lib/systemd/system/set_emu_param.service && \
  sed -i 's/\/run\/log/\/var\/log/i' /usr/lib/systemd/system/mlx_ipmid.service && \
  echo "hugetlbfs:x:$(getent group hugetlbfs | cut -d: -f3):openvswitch" >> /etc/group && \
  sed -i 's/${tmpdir}/${TMP_DIR}/' /usr/bin/bfcfg && \
  echo "L+ /opt/mellanox - - - - /usr/opt/mellanox" > /etc/tmpfiles.d/link-opt.conf && \
  checkmodule -M -m -o /tmp/sfc_controller.mod /tmp/sfc_controller.te && \
  semodule_package -o /tmp/sfc_controller.pp -m /tmp/sfc_controller.mod && \
  semodule -i /tmp/sfc_controller.pp && \
  rm -f /tmp/sfc_controller.te /tmp/sfc_controller.mod /tmp/sfc_controller.pp && \
  #
  # Patch Openvswitch permissions (Workaround)
  sed -i '/OVS_USER_ID/c\OVS_USER_ID="root:root"' /etc/sysconfig/openvswitch && \
  sed -i '/su/c\su root root' /etc/logrotate.d/openvswitch && \
  # Create a directory for BFB update scripts
  mkdir -p /opt/mellanox/bfb

COPY bfb/bfb-build/common/install.env/atf-uefi /opt/mellanox/bfb
COPY bfb/bfb-build/common/install.env/bmc /opt/mellanox/bfb
COPY bfb/bfb-build/common/install.env/nic-fw /opt/mellanox/bfb
COPY assets/infojson.sh /opt/mellanox/bfb/infojson.sh

RUN chmod +x /usr/bin/reload_mlx.sh; \
  chmod +x /usr/bin/install-rhcos.sh; \
  systemctl enable acpid.service || true; \
  systemctl enable mlx_ipmid.service || true; \
  systemctl enable set_emu_param.service || true;

RUN bash /opt/mellanox/bfb/infojson.sh > /opt/mellanox/bfb/info.json

# Finalize the container image
RUN set -xe; kver=$(ls /usr/lib/modules); env DRACUT_NO_XATTR=1 dracut -vf /usr/lib/modules/$kver/initramfs.img "$kver"; \
  rm /opt && ln -s /var/opt /opt; \
  dnf clean all -y && \
  rm -rf /var/cache/* /var/log/* /etc/machine-id && \
  find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -exec rm -rf {} + && \
  rm -rf /usr/share/man /usr/share/doc /usr/share/vim && \
  update-pciids && \
  ostree container commit

LABEL "rhcos.version"="${RHCOS_VERSION}"
LABEL "rhcos.doca.version"="${D_DOCA_VERSION}"
LABEL "com.coreos.osname"=rhcos
LABEL "rhcos.custom.tag"="${IMAGE_TAG}"
LABEL "org.opencontainers.image.version"="${COREOS_OPENCONTAINERS_IMAGE_VERSION}"
