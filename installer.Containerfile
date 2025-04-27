ARG RHCOS_VERSION
FROM rhcos-bfb:${RHCOS_VERSION}-latest as rhcos_bfb

FROM registry.access.redhat.com/ubi9-minimal

COPY --from=rhcos_bfb /usr/lib/modules /usr/lib/modules

# RUN rm -f /usr/lib/modules/*/initramfs.img

WORKDIR /

RUN microdnf install -y gzip efibootmgr kmod util-linux cpio && \
  microdnf download binutils && \
  rpm2cpio binutils*.rpm | cpio -idm && \
  rm -f binutils-*.rpm

RUN microdnf clean all && \
  microdnf remove -y lua-libs rpm-libs libmodulemd microdnf cpio rpm file-libs libsolv libdnf sqlite-libs \
  gnupg librepo gpgme dejavu-sans-fonts langpacks-core-font-en langpacks-en langpacks-core-en \
  fonts-filesystem && \
  rm -rf /usr/share/licenses /usr/share/man /usr/share/fonts

