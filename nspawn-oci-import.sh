#!/usr/bin/env bash
set -euo pipefail
mkdir -p /run/nspawn-oci

skopeo_output=$(echo /run/nspawn-oci/$1 | sed s.://./.g)
mkdir -p $skopeo_output
skopeo copy $1 oci:$skopeo_output:latest

umoci_output=/run/nspawn-oci/$2
rm -rf $umoci_output
umoci --verbose unpack --image $skopeo_output $umoci_output

mkdir -p /etc/systemd/system/systemd-nspawn@$2.service.d/
override=/etc/systemd/system/systemd-nspawn@$2.service.d/override.conf
cat << end > $override
[Service]
ExecStart=systemd-nspawn --oci-bundle=/var/lib/machines/%i --machine %i
end

machinectl import-fs $umoci_output $2
echo "$2 created from $1. start/enable via systemd-nspawn@$2.service"