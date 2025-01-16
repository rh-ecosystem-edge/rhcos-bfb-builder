FROM $RHCOS_CONTAINER

ARG KERNEL

COPY workspace/rhel.repo /etc/yum.repos.d
COPY workspace/doca.repo /etc/yum.repos.d
COPY workspace/docker.repo /etc/yum.repos.d
COPY workspace/kubernetes.repo /etc/yum.repos.d

# RUN dnf install -y \
#         kernel-rpm-macros

# RUN dnf install -y \
#         kernel-core-${KERNEL} \
#         kernel-modules-core-${KERNEL} \
#         kernel-${KERNEL} \
#         kernel-headers-${KERNEL} \
#         kernel-devel-${KERNEL}

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
# EPEL is required for strongswan 

RUN dnf install -y \
  kmod \
  mmc-utils \
  shim \
  sysstat \
  pciutils \
  ipmitool \
  kexec-tools \
  mokutil \
  net-tools

RUN dnf install -y \
  mft-autocomplete \ 
  mstflint \
  mlxbf-bootimages-signed \
  bf2-bmc-fw-signed bf3-bmc-fw-signed  \
  bf2-cec-fw-signed bf3-cec-fw-signed \
  mlxbf-bootctl

# Uninstall RHCOS packages: openvswitch (fdp), runc
RUN dnf remove -y \
  openvswitch*.el9fdp* \
  runc*rhaos4*

RUN dnf install -y \
  containerd.io \
  runc \
  cri-tools \
  openvswitch \
  doca-runtime \
  doca-runtime-user \
  doca-openvswitch \
  mlnx-snap
  
# bf3-bmc-gi-signed  bf3-bmc-nic-fw* mlnx-fw-updater-signed # Fails to download
# Manual installs (Until nvidia fixes their repo data)
RUN dnf install -y \
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/mlnx-fw-updater-signed-24.10-1.1.4.0.1.aarch64.rpm \
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-gi-signed-4.9.1-1.noarch.rpm \
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3b6-00cv-a-alt-il1-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3b6-00cv-a-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3b6-00sv-a-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3c6-00cv-da0-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3c6-00cv-ga0-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3c6-00sv-da-ax-4.9.1-1.noarch.rpm	\
  https://linux.mellanox.com/public/repo/doca/2.9.1/rhel9.2/arm64-dpu/bf3-bmc-nic-fw-900-9d3c6-00sv-ga-ax-4.9.1-1.noarch.rpm


RUN systemctl enable openvswitch.service || true
RUN systemctl enable mlx_ipmid.service || true
RUN systemctl enable set_emu_param.service || true
RUN systemctl enable mst || true
RUN systemctl enable watchdog.service || true
RUN systemctl disable kubelet || true
RUN systemctl disable containerd || true

RUN dnf -y clean all && \
  rm -rf /var/cache/* /etc/machine-id /etc/yum/vars/infra /etc/BUILDTIME /root/anaconda-post.log /root/*.cfg && \
  truncate -s0 /etc/machine-id && \
  update-pciids && \
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config    



RUN ostree container commit

