ARG BUILDER_IMAGE
ARG TARGET_IMAGE

FROM ${BUILDER_IMAGE} AS builder

ARG D_DOCA_VERSION

ARG D_SOC_BASE_URL="https://linux.mellanox.com/public/repo/doca/${D_DOCA_VERSION}/SOURCES/SoC"

COPY workspace/rhel.repo /etc/yum.repos.d

RUN dnf install -y perl jq iproute kmod procps-ng udev \
  autoconf gcc make rpm-build rpmdevtools wget fuse fuse-libs fuse-devel && \
  dnf clean all

RUN mkdir -p /build/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} && \
  wget -r -np -e robots=off -A "*.rpm" -nd -P /build/rpmbuild/SRPMS ${D_SOC_BASE_URL}/SRPMS && \
  dnf builddep -y /build/rpmbuild/SRPMS/*.src.rpm

RUN export HOME=/build && \
  export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
  for rpm in /build/rpmbuild/SRPMS/*.src.rpm; do \
  echo "Rebuilding $rpm with kernel version $KVER"; \
  rpmbuild --rebuild --define "KVERSION $KVER" "$rpm" || exit 1; \
  done

# RUN HOME=/build rpmbuild --rebuild /build/rpmbuild/SRPMS/mlx-OpenIPMI-2.0.25-3.g7cdecd6.src.rpm
# RUN export HOME=/build && \
#   export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
#   rpmbuild --rebuild --define "KVERSION $KVER" /build/rpmbuild/SRPMS/tmfifo-1.7-0.g245d395.src.rpm

# RUN export HOME=/build && \
#   export KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel)" && \
#   rpmbuild --rebuild --define "KVERSION $KVER" /build/rpmbuild/SRPMS/bluefield_edac-1.0-0.g71f1ab8.src.rpm

RUN wget -P /build/rpmbuild/RPMS https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/dpu-arm64/libibverbs-2410mlnx54-1.2410068.aarch64.rpm

RUN echo "Files in /example directory:" && ls /build/rpmbuild/RPMS/aarch64

FROM ${TARGET_IMAGE} AS base

COPY workspace/rhel.repo /etc/yum.repos.d
COPY workspace/doca.repo /etc/yum.repos.d
COPY workspace/docker.repo /etc/yum.repos.d
COPY workspace/kubernetes.repo /etc/yum.repos.d
# COPY --from=builder /build/rpmbuild/RPMS/aarch64/*.rpm /root/

# RUN rm /root/*debuginfo*.rpm /root/*debugsource*.rpm

# RUN rpm -ivh --nodeps /root/*.rpm && rm /root/*.rpm

COPY --from=builder /build/rpmbuild/RPMS/*.rpm /root/

RUN rpm-ostree install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# uninstalling conflicting packages...
RUN rpm-ostree override remove openvswitch3.1 && \
  rpm-ostree override remove openvswitch-selinux-extra-policy && \
  rpm-ostree override remove cri-o && \
  rpm-ostree override remove runc

RUN rpm-ostree override replace /root/libibverbs-2410mlnx54-1.2410068.aarch64.rpm
# Getting rid of default libibverbs

# RUN rm /opt && mkdir -p /var/opt && ln -s /var/opt /opt
# In RHCOS /opt is symlink to /var/opt, but in this build process it is broken for some reason.
RUN rm /opt && mkdir /opt

# RUN rpm-ostree install dnf && \
  # dnf install -y \ 
RUN rpm-ostree install \
  doca-runtime \
  mmc-utils \
  ipmitool \
  mstflint \
  mft-autocomplete \
  bf2-bmc-fw-signed bf3-bmc-fw-signed \
  bf2-cec-fw-signed bf3-cec-fw-signed \
  bf3-bmc-gi-signed  bf3-bmc-nic-fw* mlnx-fw-updater-signed


RUN systemctl enable openvswitch.service || true
RUN systemctl enable mlx_ipmid.service || true
RUN systemctl enable set_emu_param.service || true
# RUN systemctl enable mst || true
RUN systemctl enable watchdog.service || true
# RUN systemctl disable kubelet || true
RUN systemctl disable containerd || true

RUN rm -rf \
  /var/cache/* \
  /etc/machine-id \
  /etc/yum/vars/infra \
  /etc/BUILDTIME \
  /root/anaconda-post.log \
  /root/*.cfg \
  /root/*.rpm && \
  truncate -s0 /etc/machine-id && \
  update-pciids

RUN rm -rf /var/ipmi_sim/mellanox /var/lib/kubelet/config.yaml
# The doca and dependencies installed files in /var.

RUN ostree container commit
