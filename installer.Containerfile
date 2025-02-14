FROM rhcos-bfb:latest as rhcos_bfb

FROM registry.access.redhat.com/ubi9-minimal

COPY --from=rhcos_bfb /usr/lib/modules /usr/lib/modules

# RUN rm -f /usr/lib/modules/*/initramfs.img

RUN cat <<EOF > /etc/yum.repos.d/centos-stream.repo
[centos-stream-baseos]
name=CentOS Stream 9 - BaseOS
baseurl=https://mirror.stream.centos.org/9-stream/BaseOS/\$basearch/os/
gpgcheck=0
enabled=1
EOF

WORKDIR /

RUN microdnf install -y gzip efibootmgr kmod util-linux cpio && \
  microdnf download binutils && \
  rpm2cpio binutils*.rpm | cpio -idm && \
  rm -f binutils-*.rpm

COPY bfb/init.sh /init
COPY bfb/install_rhcos.sh /usr/bin/install_rhcos.sh

RUN chmod +x /init && \
  chmod +x /usr/bin/install_rhcos.sh

RUN microdnf clean all && \
  microdnf remove -y lua-libs rpm-libs libmodulemd microdnf cpio rpm file-libs libsolv libdnf sqlite-libs \
  gnupg librepo gpgme dejavu-sans-fonts langpacks-core-font-en langpacks-en langpacks-core-en \
  fonts-filesystem && \
  rm -rf /usr/share/licenses /usr/share/man /usr/share/fonts

