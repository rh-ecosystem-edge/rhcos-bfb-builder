ARG BUILDER_IMAGE
ARG TARGET_IMAGE

FROM ${BUILDER_IMAGE} AS builder

ARG D_DOCA_VERSION

ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"
ARG D_DOCA_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/MLNX_OFED"

COPY workspace/rhel.repo /etc/yum.repos.d

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
# EPEL for rpmrebuild

RUN dnf install -y perl jq iproute kmod procps-ng udev \
  autoconf automake gcc make rpm-build rpmdevtools wget fuse fuse-libs fuse-devel rpmrebuild kernel-abi-stablelists

RUN mkdir -p /build/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

RUN wget -r -np -e robots=off --reject-regex '(\?C=|index\.html)' -A "*.rpm" -nv -nd -P /build/rpmbuild/SRPMS ${D_SOC_BASE_URL}/SRPMS

RUN PACKAGES=("fwctl" "iser" "isert" "knem" "xpmem" "mlnx-ofa_kernel" "mlnx-nfsrdma" "mlnx-nvme" "srp" "kernel-mft") && \ 
  PATTERNS=$(IFS=,; echo "${PACKAGES[*]/%/-*.src.rpm}") && \
  wget -c -r -l1 -np -nH --cut-dirs=1 --reject-regex '(\?C=|index\.html)' -nd -P /build/rpmbuild/SRPMS -nv -A  "$PATTERNS" "$D_DOCA_BASE_URL/SRPMS"

RUN dnf builddep -y /build/rpmbuild/SRPMS/*.src.rpm

RUN PACKAGE="mlnx-ofa_kernel" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm && \
  dnf install -y /build/rpmbuild/RPMS/aarch64/mlnx-ofa_kernel*.rpm

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

RUN PACKAGE="mlnx-nfsrdma" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm

RUN PACKAGE="mlnx-nvme" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm


# knem builds two packages
RUN PACKAGE="knem" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-$PACKAGE/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm && \
  rm /build/rpmbuild/RPMS/aarch64/$PACKAGE-modules-*.aarch64.rpm


  

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

RUN PACKAGE="kernel-mft" && \
  export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  rpmbuild --rebuild --define "KVERSION $KVER" --define "debug_package %{nil}" /build/rpmbuild/SRPMS/$PACKAGE-*.src.rpm && \
  rpmrebuild -p --change-spec-preamble "sed -e \"s/^Name:.*/Name: kmod-kernel-mft-mlnx/\"" /build/rpmbuild/RPMS/aarch64/$PACKAGE-*.aarch64.rpm && \
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


  #   sdhci-of-dwcmshc-1.0-0.gbf48908.src.rpm
# RUN export HOME=/build && \
#   export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
#   rpmbuild --rebuild --define "KVERSION $KVER" /build/rpmbuild/SRPMS/bluefield_edac-1.0-0.g71f1ab8.src.rpm

RUN echo "RPMs:" && ls /build/rpmbuild/RPMS/aarch64
RUN echo "SRPMs" && ls /build/rpmbuild/SRPMS

COPY --from=builder /build/rpmbuild/RPMS/aarch64 final
