ARG D_BASE_IMAGE
ARG D_FINAL_BASE_IMAGE
ARG D_OS="rhcos4.17"
# ARG D_RHEL_VER="9.4"
ARG D_ARCH="aarch64"
ARG D_CONTAINER_VER="0"
ARG D_DOCA_VERSION="2.10.0"
ARG D_OFED_VERSION="25.01-0.6.0.0"
ARG D_KERNEL_VER="5.14.0-427.50.1.el9_4.${D_ARCH}"
ARG D_OFED_SRC_DOWNLOAD_PATH="/run/mellanox/src"
ARG OFED_SRC_LOCAL_DIR=${D_OFED_SRC_DOWNLOAD_PATH}/MLNX_OFED_SRC-${D_OFED_VERSION}

FROM $D_BASE_IMAGE AS builder

ARG D_OS
# ARG D_RHEL_VER
ARG D_KERNEL_VER
ARG D_DOCA_VERSION
ARG D_OFED_VERSION
ARG D_CONTAINER_VER
ARG D_OFED_SRC_DOWNLOAD_PATH
ARG OFED_SRC_LOCAL_DIR

ARG D_OFED_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/MLNX_OFED"
ARG D_OFED_SRC_TYPE=""
ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"

RUN rm /etc/yum.repos.d/ubi.repo

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
ARG D_OFED_VERSION
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR
ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"

RUN mkdir -p /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-ofa_kernel-devel*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-ofa_kernel-source*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/ofed-scripts*.rpm /root/mofed-rpms
COPY --from=builder ${OFED_SRC_LOCAL_DIR}/RPMS/redhat-release-*/${D_ARCH}/mlnx-tools*.rpm /root/mofed-rpms

RUN rm /etc/yum.repos.d/ubi.repo
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

RUN dnf install -y autoconf automake gcc make rpm-build rpmdevtools rpmrebuild libtool

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

COPY patches/sdhci-of-dwcmshc-patch1.patch /build/rpmbuild/SOURCES

RUN PACKAGE="sdhci-of-dwcmshc" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  mkdir /tmp/$PACKAGE && cd /tmp/$PACKAGE && \
  rpm2cpio /build/rpmbuild/SRPMS/$PACKAGE*.src.rpm | cpio -idmv && \
  rm -fv /build/rpmbuild/SRPMS/$PACKAGE*.src.rpm && \
  tar -xf $PACKAGE-*.tar.gz && rm -f $PACKAGE-*.tar.gz && \
  patch sdhci-of-dwcmshc-1.0/sdhci.c < /build/rpmbuild/SOURCES/sdhci-of-dwcmshc-patch1.patch && \
  tar -czf /build/rpmbuild/SOURCES/$PACKAGE-1.0.tar.gz sdhci-of-dwcmshc-1.0 && \
  rm -rf sdhci-of-dwcmshc-1.0 && \
  mv $PACKAGE.spec /build/rpmbuild/SPECS && \
  rpmbuild -bs /build/rpmbuild/SPECS/$PACKAGE.spec && \
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

WORKDIR /tmp

RUN PACKAGES=("fwctl" "iser" "isert" "knem" "xpmem" "srp") && \
  TARFILE=MLNX_OFED_SRC-$D_OFED_VERSION.tgz && \
  wget -P /tmp "$D_OFED_BASE_URL/$TARFILE" && \
  tar --wildcards -xzf "$TARFILE" -C "/build/rpmbuild" $(for pkg in "${PACKAGES[@]}"; do echo "${TARFILE%.*}/SRPMS/${pkg}-*.src.rpm"; done) \
  --exclude='SRPMS/xpmem-lib-*.src.rpm' --strip-components=1


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

RUN PACKAGE="srp" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

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
# ARG D_RHEL_VER
ARG D_KERNEL_VER
ARG D_DOCA_VERSION
ARG D_DOCA_DISTRO
ARG D_ARCH
ARG OFED_SRC_LOCAL_DIR

RUN dnf config-manager --set-enabled codeready-builder-for-rhel-9-$(uname -m)-rpms || \
  dnf config-manager --set-enabled codeready-builder-beta-for-rhel-9-$(uname -m)-rpms

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

RUN rm -f /tmp/rpms/mlnx-ofa_kernel-devel*.rpm \
  /tmp/rpms/kmod-mlnx-ofa_kernel-debuginfo*.rpm \
  /tmp/rpms/mlnx-ofa_kernel-debugsource*.rpm \
  /tmp/rpms/mlnx-ofa_kernel-source*.rpm \
  /tmp/rpms/*-devel*.rpm && \
  rpm -ivh --nodeps /tmp/rpms/*.rpm

RUN dnf remove -y openvswitch-selinux-extra-policy openvswitch*

WORKDIR /root

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
  # && rpm -e --nodeps libnl3-devel kernel-headers libzstd-devel ncurses-devel
# virtio-net-controller \


RUN dnf download \
  doca-runtime doca-runtime-kernel doca-runtime-user \
  # doca-devel doca-devel-kernel doca-devel-user \
  bf-release && \
  rpm -ivh --nodeps \
  doca-runtime-kernel-${D_DOCA_VERSION}*.${D_ARCH}.rpm \
  doca-runtime-user*.${D_ARCH}.rpm \
  doca-runtime-${D_DOCA_VERSION}*.${D_ARCH}.rpm
# doca-runtime-kernel and doca-devel-kernel are still tied to specific kernel, but we compiled these on our own, so we ignore the specific version dependency
# doca-runtime-user requires it's own doca-openvswitch packages, and requires bf-release

RUN mkdir /tmp/bf-release; \
  rpm2cpio bf-release-*.aarch64.rpm | cpio -idm -D /tmp/bf-release; \
  rm -rf /tmp/bf-release/var /tmp/bf-release/usr/lib/systemd /tmp/bf-release/usr/share \
  /tmp/bf-release/etc/NetworkManager \
  /tmp/bf-release/etc/crictl* /tmp/bf-release/etc/kubelet.d /tmp/bf-release/etc/cni; \
  cp -rnv /tmp/bf-release/* /; \
  echo "bf-bundle-${D_DOCA_VERSION}_${D_OS}" > /etc/mlnx-release
# Install bf-release in a hacky way

RUN dnf install -y \
  acpid \
  bridge-utils \
  mstflint \
  mft-autocomplete \
  mlnx-snap \
  mmc-utils \
  device-mapper \
  edac-utils \
  lm_sensors \
  efibootmgr \
  i2c-tools \ 
  ipmitool \ 
  ebtables-legacy iptables-legacy \
  nvmetcli\
  bf2-bmc-fw-signed bf3-bmc-fw-signed bf3-bmc-gi-signed bf3-bmc-nic-fw* \
  bf2-cec-fw-signed bf3-cec-fw-signed \
  && dnf clean all

ARG D_UBUNTU_BASEURL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/ubuntu22.04/arm64-dpu/"
RUN PACKAGE=$(curl ${D_UBUNTU_BASEURL} | grep -oP 'href="\Ksfc-hbn[^"]+') && \
  curl -O "${D_UBUNTU_BASEURL}/${PACKAGE}" && \
  ar x $PACKAGE data.tar.zst && \
  tar --keep-directory-symlink -xf data.tar.zst -C / && \
  rm -f $PACKAGE

RUN PACKAGE=$(curl ${D_UBUNTU_BASEURL} | grep -oP 'href="\Kdoca-dms[^"]+') && \
  curl -O "${D_UBUNTU_BASEURL}/${PACKAGE}" && \
  ar x $PACKAGE data.tar.zst && \
  tar --keep-directory-symlink -xf data.tar.zst -C / && \
  rm -f $PACKAGE

# Temporary hack to reload mlx5_core
COPY assets/reload_mlx.service /usr/lib/systemd/system
COPY assets/reload_mlx.sh /usr/bin/reload_mlx.sh
COPY assets/doca-ovs_sfc.te /tmp/sfc_controller.te

RUN sed -i 's/\/run\/log/\/var\/log/i' /usr/bin/mlx_ipmid_init.sh && \
  sed -i 's/\/run\/log/\/var\/log/i' /usr/lib/systemd/system/set_emu_param.service && \
  sed -i 's/\/run\/log/\/var\/log/i' /usr/lib/systemd/system/mlx_ipmid.service

RUN cp /usr/share/doc/mlnx-ofa_kernel/vf-net-link-name.sh /etc/infiniband/vf-net-link-name.sh && \
  cp /usr/share/doc/mlnx-ofa_kernel/82-net-setup-link.rules /usr/lib/udev/rules.d/82-net-setup-link.rules && \
  echo "hugetlbfs:x:$(getent group hugetlbfs | cut -d: -f3):openvswitch" >> /etc/group && \
  echo "L+ /opt/mellanox - - - - /usr/opt/mellanox" > /etc/tmpfiles.d/link-opt.conf && \
  checkmodule -M -m -o /tmp/sfc_controller.mod /tmp/sfc_controller.te && \
  semodule_package -o /tmp/sfc_controller.pp -m /tmp/sfc_controller.mod && \
  semodule -i /tmp/sfc_controller.pp && \
  rm -f /tmp/sfc_controller.te /tmp/sfc_controller.mod /tmp/sfc_controller.pp

RUN chmod +x /usr/bin/reload_mlx.sh; \
  systemctl enable acpid.service || true; \
  systemctl enable dmsd.service || true; \
  systemctl enable mlx_ipmid.service || true; \
  systemctl enable set_emu_param.service || true; \
  systemctl enable reload_mlx.service || true; \
  systemctl disable bfvcheck.service || true; \
  sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

  # RUN systemctl enable mst || true



# RUN echo 'omit_drivers+=" mlx4_core mlx4_en mlx5_core mlxbf_gige.ko mlxfw "' >> /usr/lib/dracut/dracut.conf.d/50-mellanox-overrides.conf 
# RUN set -x; kver=$(cd /usr/lib/modules && echo *); \
#   depmod -a $kver && \
#   dracut -vf /usr/lib/modules/$kver/initramfs.img $kver

# Restore /opt
RUN rm /opt && ln -s /var/opt /opt

# Reduce final size
RUN dnf remove -y \
  geolite2-city \
  ose-azure-acr-image-credential-provider \
  ose-aws-ecr-image-credential-provider \
  ose-gcp-gcr-image-credential-provider && \
  dnf clean all -y && \
  rm -rf /var/cache/* /var/log/* /etc/machine-id /etc/yum/vars/infra /etc/BUILDTIME /root/anaconda-post.log /root/*.cfg && \
  rm -f /etc/machine-id && \
  find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -exec rm -rf {} + && \
  update-pciids

RUN ostree container commit
