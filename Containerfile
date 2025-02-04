ARG D_BASE_IMAGE
ARG D_FINAL_BASE_IMAGE
ARG D_OS="rhcos4.17"
ARG D_ARCH="aarch64"
ARG D_CONTAINER_VER="0"
ARG D_DOCA_VERSION="2.9.1"
ARG D_OFED_VERSION="24.10-1.1.4.0"
ARG D_KERNEL_VER="5.14.0-427.50.1.el9_4.${D_ARCH}"
ARG D_OFED_SRC_DOWNLOAD_PATH="/run/mellanox/src"
ARG OFED_SRC_LOCAL_DIR=${D_OFED_SRC_DOWNLOAD_PATH}/MLNX_OFED_SRC-${D_OFED_VERSION}

FROM $D_BASE_IMAGE AS builder

ARG D_OS
ARG D_KERNEL_VER
ARG D_DOCA_VERSION
ARG D_OFED_VERSION
ARG D_CONTAINER_VER
ARG D_OFED_SRC_DOWNLOAD_PATH
ARG OFED_SRC_LOCAL_DIR

ARG D_OFED_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/MLNX_OFED"
ARG D_OFED_SRC_TYPE=""
ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"

COPY assets/create_repos.sh /tmp/create_repos.sh
RUN bash /tmp/create_repos.sh

ARG D_OFED_SRC_ARCHIVE="MLNX_OFED_SRC-${D_OFED_SRC_TYPE}${D_OFED_VERSION}.tgz"
ARG D_OFED_URL_PATH="${D_OFED_BASE_URL}/${D_OFED_SRC_ARCHIVE}"  # although argument name says URL, local `*.tgz` compressed files may also be used (intended for internal use)

ENV NVIDIA_NIC_DRIVER_VER=${D_OFED_VERSION}
ENV NVIDIA_NIC_CONTAINER_VER=${D_CONTAINER_VER}
ENV NVIDIA_NIC_DRIVER_PATH="${D_OFED_SRC_DOWNLOAD_PATH}/MLNX_OFED_SRC-${D_OFED_VERSION}"

WORKDIR /root

RUN dnf install -y autoconf python3-devel ethtool automake pciutils libtool hostname dracut \
  rpm-build make gcc \
  perl jq iproute kmod procps udev


RUN echo mkdir -p "$D_OFED_SRC_DOWNLOAD_PATH"
RUN mkdir -p "$D_OFED_SRC_DOWNLOAD_PATH"

WORKDIR ${D_OFED_SRC_DOWNLOAD_PATH}
ADD ${D_OFED_URL_PATH} ${D_OFED_SRC_ARCHIVE}

RUN if file ${D_OFED_SRC_ARCHIVE} | grep compressed; then \
  tar -xzf ${D_OFED_SRC_ARCHIVE}; \
  else \
  mv ${D_OFED_SRC_ARCHIVE}/MLNX_OFED_SRC-${D_OFED_VERSION} . ; \
  fi


RUN ls ${OFED_SRC_LOCAL_DIR}
RUN set -x && \
  ${OFED_SRC_LOCAL_DIR}/install.pl --without-depcheck --distro ${D_OS} --kernel ${D_KERNEL_VER} --kernel-sources /lib/modules/${D_KERNEL_VER}/build --kernel-only --build-only --without-iser --without-srp --without-isert --without-knem --without-xpmem --with-mlnx-tools --with-ofed-scripts --copy-ifnames-udev

###################################

FROM $D_BASE_IMAGE AS doca-builder

ARG D_OS
ARG D_KERNEL_VER
ARG D_DOCA_VERSION
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR
ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"

RUN mkdir -p /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-ofa_kernel-devel*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-ofa_kernel-source*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/ofed-scripts*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-tools*.rpm /root/mofed-rpms

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

RUN dnf install -y autoconf automake gcc make rpm-build rpmdevtools rpmrebuild

RUN rpm -ivh --nodeps /root/mofed-rpms/*.rpm

RUN mkdir -p /build/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}


RUN echo ${D_SOC_BASE_URL}/SRPMS
RUN wget -r -np -e robots=off --reject-regex '(\?C=|index\.html)' -A "*.rpm" -nv -nd -P /build/rpmbuild/SRPMS ${D_SOC_BASE_URL}/SRPMS

RUN PACKAGE="bluefield_edac" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="tmfifo" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="pwr-mlxbf" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlxbf-ptm" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlxbf-pmc" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm


RUN PACKAGE="mlxbf-livefish" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlxbf-gige" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlx-trio" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="ipmb-dev-int" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="ipmb-host" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm


RUN PACKAGE="i2c-mlxbf" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="gpio-mlxbf3" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="gpio-mlxbf2" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="gpio-mlxbf" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlx-bootctl" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="sdhci-of-dwcmshc" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

COPY patches/mlxbf-pka-patch1.patch /build/rpmbuild/SOURCES

RUN PACKAGE="mlxbf-pka" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \  
  mkdir /tmp/$PACKAGE && cd /tmp/$PACKAGE && \
  rpm2cpio /build/rpmbuild/SRPMS/mlxbf-pka-1.0-0*.src.rpm | cpio -idmv && \
  rm -f /build/rpmbuild/SRPMS/mlxbf-pka-1.0-0*.src.rpm && \
  tar -xf mlxbf-pka-1.0.tar.gz && rm -f mlxbf-pka-1.0.tar.gz && \
  patch mlxbf-pka-1.0/pka_drv_mlxbf.c < /build/rpmbuild/SOURCES/mlxbf-pka-patch1.patch && \
  tar -czf /build/rpmbuild/SOURCES/mlxbf-pka-1.0.tar.gz mlxbf-pka-1.0 && \
  rm -rf mlxbf-pka-1.0 && \
  mv mlxbf-pka.spec /build/rpmbuild/SPECS && \
  rpmbuild -bs /build/rpmbuild/SPECS/mlxbf-pka.spec && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

COPY patches/pinctrl-mlxbf3-patch1.patch /build/rpmbuild/SOURCES

RUN PACKAGE="pinctrl-mlxbf3" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \  
  mkdir /tmp/$PACKAGE && cd /tmp/$PACKAGE && \
  rpm2cpio /build/rpmbuild/SRPMS/pinctrl-mlxbf3-1.0-0*.src.rpm | cpio -idmv && \
  rm -f /build/rpmbuild/SRPMS/pinctrl-mlxbf3-1.0-0*.src.rpm && \
  tar -xf pinctrl-mlxbf3-1.0.tar.gz && rm -f pinctrl-mlxbf3-1.0.tar.gz && \
  patch -p1 < /build/rpmbuild/SOURCES/pinctrl-mlxbf3-patch1.patch && \
  tar -czf /build/rpmbuild/SOURCES/pinctrl-mlxbf3-1.0.tar.gz pinctrl-mlxbf3-1.0 && \
  rm -rf pinctrl-mlxbf3-1.0 && \
  mv pinctrl-mlxbf3.spec /build/rpmbuild/SPECS && \
  rpmbuild -bs /build/rpmbuild/SPECS/pinctrl-mlxbf3.spec && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

ARG D_OFED_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/MLNX_OFED"

RUN PACKAGES=("fwctl" "iser" "isert" "knem" "xpmem") && \ 
  PATTERNS=$(IFS=,; echo "${PACKAGES[*]/%/-*.src.rpm}") && \
  wget -c -r -l1 -np -nH --cut-dirs=1 --reject-regex '(\?C=|index\.html)' -nd -P /build/rpmbuild/SRPMS -nv -A  "$PATTERNS" "$D_OFED_BASE_URL/SRPMS" && \
  rm -rf /build/rpmbuild/SRPMS/xpmem-lib*.src.rpm

RUN PACKAGE="iser" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="isert" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="fwctl" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

# RUN PACKAGE="srp" && \
#   export HOME=/build && \
#   export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
#   rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
#   rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
#   rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN dnf install -y libtool

RUN PACKAGE="xpmem" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm

RUN PACKAGE="knem" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm

######################################################################

FROM ${D_FINAL_BASE_IMAGE} AS base

ARG D_OS
ARG D_KERNEL_VER
ARG D_DOCA_VERSION
ARG D_DOCA_DISTRO
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR

COPY assets/create_repos.sh /tmp/create_repos.sh

RUN bash /tmp/create_repos.sh

RUN cat <<EOF > /etc/yum.repos.d/doca.repo
[doca]
name=Nvidia DOCA repository
baseurl=https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/${D_DOCA_DISTRO}/arm64-dpu/
gpgcheck=0
enabled=1
EOF

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && dnf clean all
# EPEL is required for jsoncpp strongswan libunwind

RUN mkdir -p /tmp/rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/*.rpm /tmp/rpms
COPY --from=doca-builder /build/rpmbuild/RPMS/${D_ARCH}/*.rpm /tmp/rpms

WORKDIR /
RUN rm opt && mkdir -p usr/opt && ln -s usr/opt opt

# TODO: Don't install devel, debuginfo, debugsource, source packages

RUN rpm -ivh --nodeps /tmp/rpms/*.rpm

# RUN dnf remove -y openvswitch-selinux-extra-policy openvswitch* runc

WORKDIR /root

RUN dnf -y install \
  # bf-release \
  collectx-clxapi \
  doca-apsh-config \
  doca-bench \
  doca-caps \
  doca-comm-channel-admin \
  doca-dms \
  doca-flow-tune \
  # doca-openvswitch \
  # doca-openvswitch-ipsec \
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
  dpaeumgmt \
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
  # libxpmem \
  meson \
  mft \
  mft-oem \
  mlnx-dpdk \
  mlnx-ethtool \
  mlnx-iproute2 \
  mlnx-libsnap \
  mlx-OpenIPMI \
  mlxbf-bfscripts \
  mlxbf-bootctl \
  ofed-scripts \
  opensm \
  opensm-libs \
  opensm-static \
  perftest \
  # python3-doca-openvswitch \
  rdma-core \
  spdk \
  srp_daemon \
  ucx \
  ucx-cma \
  ucx-ib \
  ucx-knem \
  ucx-rdmacm \
  ucx-xpmem \
  && dnf clean all
# virtio-net-controller \


RUN dnf download \
  doca-runtime doca-runtime-kernel doca-runtime-user \
  # doca-devel doca-devel-kernel doca-devel-user \
  bf-release

RUN rpm -ivh --nodeps doca-runtime-kernel-${D_DOCA_VERSION}*.${D_ARCH}.rpm
# doca-runtime-kernel and doca-devel-kernel are still tied to specific kernel, but we compiled these on our own, so we ignore the specific version dependency

RUN rpm -ivh --nodeps doca-runtime-user*.${D_ARCH}.rpm
# doca-runtime-user requires it's own doca-openvswitch packages, and requires bf-release

RUN rpm -ivh doca-runtime-${D_DOCA_VERSION}*.${D_ARCH}.rpm


RUN dnf install -y \
  mstflint \
  mft-autocomplete \
  mlnx-snap \
  pciutils usbutils \ 
  net-tools iproute-tc \
  mmc-utils \
  device-mapper \
  edac-utils \
  efibootmgr \
  i2c-tools \ 
  ipmitool \ 
  iproute-tc \
  kexec-tools kmod \
  jq \
  mokutil \
  nfs-utils \ 
  nvme-cli nvmetcli\
  bf2-bmc-fw-signed bf3-bmc-fw-signed bf3-bmc-gi-signed bf3-bmc-nic-fw* \
  bf2-cec-fw-signed bf3-cec-fw-signed \
  python3-devel \
  && dnf clean all
# python3-devel required for pathfix.py (create_bfb)


RUN systemctl enable mlx_ipmid.service || true; \
systemctl enable set_emu_param.service || true
# RUN systemctl enable mst || true

RUN mkdir /root/workspace

RUN dnf clean all -y && \
  rm -rf /var/cache/* /etc/machine-id /etc/yum/vars/infra /etc/BUILDTIME /root/anaconda-post.log /root/*.cfg && \
  truncate -s0 /etc/machine-id \
  update-pciids

RUN ostree container commit
