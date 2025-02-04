#!/bin/bash

RHEL_VER=9.4

REPO_FILE=/etc/yum.repos.d/rhel.repo

repos=(
  "baseos"
  "appstream"
  "codeready-builder"
)

for repo in ${repos[@]}; do
  echo "[rhel-$RHEL_VER-$repo]" >> $REPO_FILE
  echo "name=Red Hat Enterprise Linux $RHEL_VER - $repo" >> $REPO_FILE
  echo "baseurl=https://rhsm-pulp.corp.redhat.com/content/eus/rhel9/$RHEL_VER/\$basearch/$repo/os/" >> $REPO_FILE
  echo "enabled=1" >> $REPO_FILE
  echo "gpgcheck=1" >> $REPO_FILE
  echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $REPO_FILE
  echo -e "\n" >> $REPO_FILE
done

