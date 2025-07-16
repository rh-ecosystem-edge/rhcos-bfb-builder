CONTAINER_IMAGE="localhost/rhcos-bfb:${RHCOS_VERSION}-latest"

check_file_exists() {
    local file_path="$1"
    podman run -it --rm $CONTAINER_IMAGE bash -c "[ -e \"$file_path\" ]"
}

run_container() {
    local command="$1"
    podman run -it --rm $CONTAINER_IMAGE bash -c "$command"
}

build_infojson() {
    BFB=$WDIR/bootimages/lib/firmware/mellanox/boot/default.bfb
    bfver_out="$( bfver --file ${BFB} )"

    ATF_VERSION=$( echo "$bfver_out" | grep -m 1 "ATF" | cut -d':' -f 3 | \
        sed -e 's/[[:space:]]//' )
    UEFI_VERSION=$( echo "$bfver_out" | grep -m 1 "UEFI" | cut -d':' -f 2 | \
        sed -e 's/[[:space:]]//' )

    json_output=$(jq -n \
    --arg bf3_bsp_version "$ATF_UEFI_VERSION" \
    --arg bf3_bsp_source "${CAPSULE##*/}" \
    --arg bf2_bsp_version "$ATF_UEFI_VERSION" \
    --arg bf2_bsp_source "${CAPSULE##*/}" \
    --arg bf3_atf_version "$ATF_VERSION" \
    --arg bf3_atf_source "${CAPSULE##*/}" \
    --arg bf2_atf_version "$ATF_VERSION" \
    --arg bf2_atf_source "${CAPSULE##*/}" \
    --arg bf3_uefi_version "$UEFI_VERSION" \
    --arg bf3_uefi_source "${CAPSULE##*/}" \
    --arg bf2_uefi_version "$UEFI_VERSION" \
    --arg bf2_uefi_source "${CAPSULE##*/}" \
    '{
        "//": "This JSON represents a Redfish Software Inventory collection containing multiple software components.",
        "@odata.type": "#SoftwareInventoryCollection.SoftwareInventoryCollection",
        "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory",
        "Name": "BFB File Content",
        "Members": [
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/1",
                "Id": "1",
                "Name": "BF3_BSP",
                "Version": $bf3_bsp_version,
                "SoftwareId": $bf3_bsp_source,
            },
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/2",
                "Id": "2",
                "Name": "BF2_BSP",
                "Version": $bf2_bsp_version,
                "SoftwareId": $bf2_bsp_source,
            },
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/3",
                "Id": "3",
                "Name": "BF3_ATF",
                "Version": $bf3_atf_version,
                "SoftwareId": $bf3_atf_source,
            },
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/4",
                "Id": "4",
                "Name": "BF2_ATF",
                "Version": $bf2_atf_version,
                "SoftwareId": $bf2_atf_source,
            },
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/5",
                "Id": "5",
                "Name": "BF3_UEFI",
                "Version": $bf3_uefi_version,
                "SoftwareId": $bf3_uefi_source,
            },
            {
                "@odata.id": "/redfish/v1/UpdateService/SoftwareInventory/6",
                "Id": "6",
                "Name": "BF2_UEFI",
                "Version": $bf2_uefi_version,
                "SoftwareId": $bf2_uefi_source,
            }
        ],
        "Members@odata.count": 6
    }')

    odata_count=6

    # if [ -e "/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41686" ]; then

    if check_file_exists "/usr/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41686"; then
        echo "Found mlxfwmanager_sriov_dis_aarch64_41686, adding BF2_NIC_FW to JSON output"
        let odata_count++
        # BF2_NIC_FW_VERSION=$(/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41686 --list 2> /dev/null | grep FW | head -1 | awk '{print $4}')
        BF2_NIC_FW_VERSION=$(run_container "/usr/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41686 --list 2> /dev/null | grep FW | head -1 | awk '{print \$4}'" | strings)

        BF2_NIC_FW="mlxfwmanager_sriov_dis_aarch64_41686"
        json_output=$( echo $json_output | jq \
            --arg odata_count "$odata_count" \
            --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
            --arg bf2_nic_fw_version "${BF2_NIC_FW_VERSION}" \
            --arg bf2_nic_fw_source "${BF2_NIC_FW##*/}" \
            '.Members += [{
                "@odata.id": $odata_id,
                "Id": $odata_count,
                "Name": "BF2_NIC_FW",
                "Version": $bf2_nic_fw_version,
                "SoftwareId": $bf2_nic_fw_source,
                }] | .["Members@odata.count"] += 1')
    fi

    if check_file_exists "/usr/lib/firmware/mellanox/cec/bf2-cec-fw.bin"; then
        let odata_count++
        BF2_CEC_FW="/usr/lib/firmware/mellanox/cec/bf2-cec-fw.bin"
        #   BF2_CEC_FW_VERSION=$(cat /usr/lib/firmware/mellanox/cec/bf2-cec-fw.version 2> /dev/null)
        BF2_CEC_FW_VERSION=$(run_container 'cat /usr/lib/firmware/mellanox/cec/bf2-cec-fw.version 2> /dev/null' | strings)

        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf2_cec_fw_version "${BF2_CEC_FW_VERSION}" \
        --arg bf2_cec_fw_source "${BF2_CEC_FW##*/}" \
        '.Members += [{
            "@odata.id": $odata_id,
            "Id": $odata_count,
            "Name": "BF2_CEC_FW",
            "Version": $bf2_cec_fw_version,
            "SoftwareId": $bf2_cec_fw_source,
        }] | .["Members@odata.count"] += 1')
    fi

    if check_file_exists "/usr/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41692"; then
      let odata_count++
    #   BF3_NIC_FW_VERSION=$(/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41692 --list 2> /dev/null | grep FW | head -1 | awk '{print $4}')
        BF3_NIC_FW_VERSION=$(run_container "/usr/opt/mellanox/mlnx-fw-updater/firmware/mlxfwmanager_sriov_dis_aarch64_41692 --list 2> /dev/null | grep FW | head -1 | awk '{print \$4}'" | strings)

        BF3_NIC_FW="mlxfwmanager_sriov_dis_aarch64_41692"
        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf3_nic_fw_version "${BF3_NIC_FW_VERSION}" \
        --arg bf3_nic_fw_source "${BF3_NIC_FW##*/}" \
        '.Members += [{
          "@odata.id": $odata_id,
          "Id": $odata_count,
          "Name": "BF3_NIC_FW",
          "Version": $bf3_nic_fw_version,
          "SoftwareId": $bf3_nic_fw_source,
          }] | .["Members@odata.count"] += 1')
    fi

    if check_file_exists "/usr/lib/firmware/mellanox/bmc/bf3-bmc-fw.fwpkg"; then
        let odata_count++
        BF3_BMC_FW="/usr/lib/firmware/mellanox/bmc/bf3-bmc-fw.fwpkg"
        #BF3_BMC_FW_VERSION=$(cat /usr/lib/firmware/mellanox/bmc/bf3-bmc-fw.version 2> /dev/null)
        BF3_BMC_FW_VERSION=$(run_container 'cat /usr/lib/firmware/mellanox/bmc/bf3-bmc-fw.version 2> /dev/null' | strings)

        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf3_bmc_fw_version "${BF3_BMC_FW_VERSION}" \
        --arg bf3_bmc_fw_source "${BF3_BMC_FW##*/}" \
        '.Members += [{
          "@odata.id": $odata_id,
          "Id": $odata_count,
          "Name": "BF3_BMC_FW",
          "Version": $bf3_bmc_fw_version,
          "SoftwareId": $bf3_bmc_fw_source,
          }] | .["Members@odata.count"] += 1')
    fi

    if check_file_exists "/usr/lib/firmware/mellanox/cec/bf3-cec-fw.fwpkg"; then
        let odata_count++
        BF3_CEC_FW="/usr/lib/firmware/mellanox/cec/bf3-cec-fw.fwpkg"
        #BF3_CEC_FW_VERSION=$(cat /usr/lib/firmware/mellanox/cec/bf3-cec-fw.version 2> /dev/null)
        BF3_CEC_FW_VERSION=$(run_container 'cat /usr/lib/firmware/mellanox/cec/bf3-cec-fw.version 2> /dev/null' | strings)

        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf3_cec_fw_version "${BF3_CEC_FW_VERSION}" \
        --arg bf3_cec_fw_source "${BF3_CEC_FW##*/}" \
        '.Members += [{
          "@odata.id": $odata_id,
          "Id": $odata_count,
          "Name": "BF3_CEC_FW",
          "Version": $bf3_cec_fw_version,
          "SoftwareId": $bf3_cec_fw_source,
          }] | .["Members@odata.count"] += 1')
    fi

    if check_file_exists "/usr/lib/firmware/mellanox/bmc/bf3-bmc-preboot-install.bfb"; then
        let odata_count++
        BF3_DPU_GI="/usr/lib/firmware/mellanox/bmc/bf3-bmc-preboot-install.bfb"
    
        BF3_DPU_GI_VERSION=$(run_container 'cat /usr/lib/firmware/mellanox/bmc/bf3-bmc-preboot-install.version 2> /dev/null' | strings)
        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf3_dpu_gi_version "${BF3_DPU_GI_VERSION}" \
        --arg bf3_dpu_gi_source "${BF3_DPU_GI##*/}" \
        '.Members += [{
            "@odata.id": $odata_id,
            "Id": $odata_count,
            "Name": "BF3_DPU_GI",
            "Version": $bf3_dpu_gi_version,
            "SoftwareId": $bf3_dpu_gi_source,
            }] | .["Members@odata.count"] += 1')
    fi

    if run_container 'ls -1 /usr/lib/firmware/mellanox/bmc/fw-BlueField-3-rel-*.bfb >/dev/null 2>&1'; then
        let odata_count++
        BF3_NIC_FW_GI=""
        #BF3_NIC_FW_GI_VERSION=$(/bin/ls -1 /usr/lib/firmware/mellanox/bmc/fw-BlueField-3-rel-*.bfb 2> /dev/null | head -1 | grep -oP '(?<=BlueField-3-rel-)\d+_\d+_\d+')
        BF3_NIC_FW_GI_VERSION=$(run_container '/bin/ls -1 /usr/lib/firmware/mellanox/bmc/fw-BlueField-3-rel-*.bfb 2> /dev/null | head -1 | grep -oP "(?<=BlueField-3-rel-)\d+_\d+_\d+"' | strings)

        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg bf3_nic_fw_gi_version "${BF3_NIC_FW_GI_VERSION}" \
        --arg bf3_nic_fw_gi_source "${BF3_NIC_FW_GI##*/}" \
        '.Members += [{
              "@odata.id": $odata_id,
              "Id": $odata_count,
              "Name": "BF3_NIC_FW_GI",
              "Version": $bf3_nic_fw_gi_version,
              "SoftwareId": $bf3_nic_fw_gi_source,
              }] | .["Members@odata.count"] += 1')
    fi

    if run_container 'rpm -q doca-runtime > /dev/null 2>&1'; then
        DOCA_VERSION=$(run_container 'rpm -q --queryformat "[%{VERSION}-%{RELEASE}]" doca-runtime')
        let odata_count++
        DOCA_SOURCE=$(run_container 'rpm -q --queryformat "[%{NAME}-%{VERSION}-%{RELEASE}]" doca-runtime')

        # WORKAROUND
        DOCA_VERSION="3.0.0058"

        json_output=$( echo $json_output | jq \
        --arg odata_count "$odata_count" \
        --arg odata_id "/redfish/v1/UpdateService/SoftwareInventory/$odata_count" \
        --arg doca_version "${DOCA_VERSION}" \
        --arg doca_source "${DOCA_SOURCE}" \
        '.Members += [{
          "@odata.id": $odata_id,
          "Id": $odata_count,
          "Name": "DOCA",
          "Version": $doca_version,
          "SoftwareId": $doca_source,
          }] | .["Members@odata.count"] += 1')
    fi

    echo "$json_output" > ${WDIR}/info.json
}
