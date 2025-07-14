ARG BUILDER_IMAGE
ARG TARGET_IMAGE
ARG RHCOS_VERSION
ARG D_ARCH
ARG D_CONTAINER_VER=0
ARG D_DOCA_VERSION
ARG D_OFED_VERSION
ARG D_OFED_SRC_DOWNLOAD_PATH="/run/mellanox/src"
ARG OFED_SRC_LOCAL_DIR=${D_OFED_SRC_DOWNLOAD_PATH}/MLNX_OFED_SRC-${D_OFED_VERSION}

FROM ${BUILDER_IMAGE} AS builder

ARG D_DOCA_VERSION
ARG D_OFED_VERSION
ARG D_CONTAINER_VER
ARG D_OFED_SRC_DOWNLOAD_PATH
ARG OFED_SRC_LOCAL_DIR


ARG D_OFED_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/MLNX_OFED"
ARG D_OFED_SRC_TYPE=""
ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/extras"

RUN KVER=$(ls /usr/lib/modules | head -n1) && \
    echo "KVER=$KVER" >> /kernelver.env  
ARG D_OFED_SRC_ARCHIVE="MLNX_OFED_SRC-${D_OFED_SRC_TYPE}${D_OFED_VERSION}.tgz"
ARG D_OFED_URL_PATH="${D_OFED_BASE_URL}/${D_OFED_SRC_ARCHIVE}"  # although argument name says URL, local `*.tgz` compressed files may also be used (intended for internal use)

ENV NVIDIA_NIC_DRIVER_VER=${D_OFED_VERSION}
ENV NVIDIA_NIC_CONTAINER_VER=${D_CONTAINER_VER}


RUN dnf install -y automake autoconf libtool perl

RUN mkdir -p "$D_OFED_SRC_DOWNLOAD_PATH"

WORKDIR ${D_OFED_SRC_DOWNLOAD_PATH}

RUN wget --no-check-certificate -O ${D_OFED_SRC_ARCHIVE} ${D_OFED_URL_PATH}

RUN if file ${D_OFED_SRC_ARCHIVE} | grep compressed; then \
  tar -xzf ${D_OFED_SRC_ARCHIVE}; \
  else \
  mv ${D_OFED_SRC_ARCHIVE}/MLNX_OFED_SRC-${D_OFED_VERSION} . ; \
  fi

RUN set -x && \
  source /kernelver.env && \
  perl ${OFED_SRC_LOCAL_DIR}/install.pl --without-depcheck --distro rhel --kernel ${KVER} --kernel-sources /lib/modules/${KVER}/build \
  --kernel-only --build-only \
  --with-iser --with-srp --with-isert --with-knem --with-xpmem --fwctl \
  --with-mlnx-tools --with-ofed-scripts --copy-ifnames-udev

RUN mkdir -p /build/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

ENV HOME=/build

WORKDIR /root

RUN SRPMS=("tmfifo" "pwr-mlxbf" "mlxbf-ptm" "gpio-mlxbf3" "mlxbf-bootctl" \
  "mlxbf-pmc" "mlxbf-livefish" "mlxbf-gige" "mlx-trio" "ipmb-dev-int" "ipmb-host" "pinctrl-mlxbf3") && \
  wget -r -np -nd -A rpm -e robots=off "${D_SOC_BASE_URL}/SRPMS" --accept-regex="$(IFS='|'; echo "(${SRPMS[*]/%/.+\.rpm})")"

RUN source /kernelver.env && \
    for package in *.src.rpm; do \
    rpmbuild --rebuild $package --define 'KMP 1' --define "KVERSION $KVER" --define "_sourcedir $(pwd)" --define "debug_package %{nil}" || exit 1; \
    rm -f $package; \
  done

RUN SRPMS_PATCH_REQUIRED=("sdhci-of-dwcmshc" "mlxbf-pka") && \
  wget -r -np -nd -A rpm -e robots=off "${D_SOC_BASE_URL}/SRPMS" --accept-regex="$(IFS='|'; echo "(${SRPMS_PATCH_REQUIRED[*]/%/.+\.rpm})")"

COPY patches/sdhci-of-dwcmshc-patch1.patch /build/rpmbuild/SOURCES

RUN source /kernelver.env && \
  PACKAGE="sdhci-of-dwcmshc" && \
  rpm2cpio $PACKAGE-*.src.rpm | cpio -idm && \
  rm -f $PACKAGE-*.src.rpm && \
  tar -xvf $PACKAGE-*.tar.gz && rm -f $PACKAGE-*.tar.gz && \
  SRCDIR=$(basename "$PACKAGE"*) && \
  patch $SRCDIR/sdhci.c < /build/rpmbuild/SOURCES/sdhci-of-dwcmshc-patch1.patch && \
  tar -czf "${SRCDIR}.tar.gz" $SRCDIR && \
  rpmbuild -ba $SRCDIR/*.spec --define 'KMP 1' --define "KVERSION $KVER" --define "_sourcedir $(pwd)" --define "debug_package %{nil}"

RUN source /kernelver.env && \
  PACKAGE="mlxbf-pka" && \
  rpm2cpio $PACKAGE-*.src.rpm | cpio -idm && \
  rm -f $PACKAGE-*.src.rpm && \
  tar -xvf $PACKAGE-*.tar.gz -o && rm -f $PACKAGE-*.tar.gz && \
  SRCDIR=$(basename "$PACKAGE"*) && \
  tar -czf "${SRCDIR}.tar.gz" $SRCDIR && \
  rpmbuild -ba $SRCDIR/*.spec --define 'KMP 1' --define 'compat_cflags -DRHEL_DRM_VERSION=6 -DRHEL_DRM_PATCHLEVEL=12' --define "KVERSION $KVER" --define "_sourcedir $(pwd)" --define "debug_package %{nil}"

######################################################################

FROM ${TARGET_IMAGE} AS base

ARG RHCOS_VERSION
ARG D_DOCA_VERSION
ARG D_DOCA_DISTRO
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR

RUN dnf config-manager --set-enabled codeready-builder-for-rhel-9-$(uname -m)-rpms || \
  dnf config-manager --set-enabled codeready-builder-beta-for-rhel-9-$(uname -m)-rpms; \
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm; \
  # EPEL is required for jsoncpp strongswan libunwind
  dnf clean all; \
  mkdir -p /tmp/rpms; \
  cat <<EOF > /etc/yum.repos.d/doca.repo
[doca]
name=Nvidia DOCA repository
baseurl=https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/${D_DOCA_DISTRO}/arm64-dpu/
gpgcheck=0
enabled=1
EOF

COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/*.rpm /tmp/rpms
COPY --from=builder /build/rpmbuild/RPMS/${D_ARCH}/*.rpm /tmp/rpms

WORKDIR /

RUN \
  # Setup /opt for package installations
  rm opt && mkdir -p usr/opt && ln -s usr/opt opt; \
  #
  # Install kernel modules
  rm -f /tmp/rpms/mlnx-ofa_kernel-devel*.rpm \
  /tmp/rpms/kmod-mlnx-ofa_kernel-debuginfo*.rpm \
  /tmp/rpms/mlnx-ofa_kernel-debugsource*.rpm \
  /tmp/rpms/mlnx-ofa_kernel-source*.rpm \
  /tmp/rpms/*-devel*.rpm \
  /tmp/rpms/*-debugsource*.rpm \
  /tmp/rpms/*-debuginfo*.rpm && \
  rpm -ivh --nodeps /tmp/rpms/*.rpm; \
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
  # Install doca-runtime meta packages without their dependencies
  cd /tmp; \
  dnf download doca-runtime doca-runtime-kernel doca-runtime-user bf-release && \
  rpm -ivh --nodeps \
  doca-runtime-kernel-${D_DOCA_VERSION}*.${D_ARCH}.rpm \
  doca-runtime-user*.${D_ARCH}.rpm \
  doca-runtime-${D_DOCA_VERSION}*.${D_ARCH}.rpm; \
  ## doca-runtime-kernel and doca-devel-kernel are still tied to specific kernel, but we compiled these on our own, so we ignore the specific version dependency
  ## doca-runtime-user requires it's own doca-openvswitch packages, and requires bf-release
  #
  # Install bf-release in a hacky way
  mkdir /tmp/bf-release; \
  rpm2cpio bf-release-*.aarch64.rpm | cpio -idm -D /tmp/bf-release; \
  rm -rf /tmp/bf-release/var /tmp/bf-release/usr/lib/systemd /tmp/bf-release/usr/share /tmp/bf-release/etc/sysconfig \
  /tmp/bf-release/etc/NetworkManager \
  /tmp/bf-release/etc/crictl* /tmp/bf-release/etc/kubelet.d /tmp/bf-release/etc/cni; \
  cp -rnv /tmp/bf-release/* /; \
  echo "bf-bundle-${D_DOCA_VERSION}_rhcos${RHCOS_VERSION}" > /etc/mlnx-release; \
  #
  dnf clean all

RUN dnf -y install \
  collectx-clxapi \
  doca-apsh-config \
  doca-bench \
  doca-caps \
  doca-comm-channel-admin \
  doca-dms \
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
  mlnx-libsnap \
  mlx-OpenIPMI \
  mlxbf-bfscripts \
  mlnx-fw-updater-signed \
  ofed-scripts \
  opensm \
  opensm-libs \
  opensm-static \
  perftest \
  rdma-core \
  spdk \
  srp_daemon \
  ucx \
  ucx-cma \
  ucx-ib \
  ucx-knem \
  ucx-rdmacm \
  ucx-xpmem \
  acpid \
  bridge-utils \
  mstflint \
  mft-autocomplete \
  mlnx-snap \
  mmc-utils \
  device-mapper \
  lm_sensors \
  efibootmgr \
  i2c-tools \ 
  ipmitool \ 
  ebtables-legacy iptables-legacy \
  nvmetcli\
  bf3-bmc-fw-signed bf3-bmc-gi-signed bf3-bmc-nic-fw* \
  bf3-cec-fw-signed \
  && dnf clean all && \
  rpm -e --nodeps libnl3-devel kernel-headers libzstd-devel ncurses-devel libpcap-devel elfutils-libelf-devel

# Temporary hack to reload mlx5_core
COPY assets/reload_mlx.service /usr/lib/systemd/system
COPY assets/reload_mlx.sh /usr/bin/reload_mlx.sh
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
  echo "L+ /opt/mellanox - - - - /usr/opt/mellanox" > /etc/tmpfiles.d/link-opt.conf && \
  checkmodule -M -m -o /tmp/sfc_controller.mod /tmp/sfc_controller.te && \
  semodule_package -o /tmp/sfc_controller.pp -m /tmp/sfc_controller.mod && \
  semodule -i /tmp/sfc_controller.pp && \
  rm -f /tmp/sfc_controller.te /tmp/sfc_controller.mod /tmp/sfc_controller.pp

RUN chmod +x /usr/bin/reload_mlx.sh; \
  chmod +x /usr/bin/install-rhcos.sh; \
  systemctl enable acpid.service || true; \
  systemctl enable dmsd.service || true; \
  systemctl enable mlx_ipmid.service || true; \
  systemctl enable set_emu_param.service || true; \
  systemctl enable reload_mlx.service || true; \
  systemctl disable bfvcheck.service || true; \
  sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config; \
  echo 'OVS_USER_ID="root:root"' >> /etc/sysconfig/openvswitch

# RUN echo 'omit_drivers+=" mlx4_core mlx4_en mlx5_core mlxbf_gige.ko mlxfw "' >> /usr/lib/dracut/dracut.conf.d/50-mellanox-overrides.conf 
# RUN set -x; kver=$(cd /usr/lib/modules && echo *); \
#   depmod -a $kver && \
#   dracut -vf /usr/lib/modules/$kver/initramfs.img $kver

# Finalize the container image
RUN rm /opt && ln -s /var/opt /opt; \
  dnf clean all -y && \
  rm -rf /var/cache/* /var/log/* /etc/machine-id && \
  find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -exec rm -rf {} + && \
  update-pciids && \
  ostree container commit

LABEL "rhcos.version"="${RHCOS_VERSION}"
LABEL "rhcos.doca.version"="${D_DOCA_VERSION}"
LABEL "rhcos.doca.distro"="${D_DOCA_DISTRO}"
LABEL "rhcos.ofed.version"="${D_OFED_VERSION}"
