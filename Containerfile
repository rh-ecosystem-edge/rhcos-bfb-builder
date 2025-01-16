FROM $RHCOS_CONTAINER

ARG KERNEL

COPY workspace/rhel.repo /etc/yum.repos.d
COPY workspace/doca.repo /etc/yum.repos.d
COPY workspace/docker.repo /etc/yum.repos.d

RUN dnf install -y \
        kernel-rpm-macros

RUN dnf install -y \
        kernel-core-${KERNEL} \
        kernel-modules-core-${KERNEL} \
        kernel-${KERNEL} \
        kernel-headers-${KERNEL} \
        kernel-devel-${KERNEL}

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
# EPEL is required for strongswan 

COPY workspace/kubernetes.repo /etc/yum.repos.d

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

    # bf3-bmc-gi-signed  bf3-bmc-nic-fw* mlnx-fw-updater-signed # Fails to download
    # doca-runtime \
    # doca-runtime-user \
    # doca-openvswitch \
    # doca-devel \
    # containerd.io 

RUN systemctl enable mst || true
# RUN systemctl enable mlx_ipmid.service 

RUN dnf -y clean all && \
    rm -rf /var/cache/* /etc/machine-id /etc/yum/vars/infra /etc/BUILDTIME /root/anaconda-post.log /root/*.cfg && \
    truncate -s0 /etc/machine-id && \
    update-pciids && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config    



RUN ostree container commit

