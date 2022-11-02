#!/usr/bin/env bash
set -euo pipefail
mkdir -p /run/nspawn-oci

skopeo_output=$(echo /run/nspawn-oci/$1 | sed s.://./.g)
mkdir -p $skopeo_output
skopeo copy $1 oci:$skopeo_output:latest

umoci_output=/run/nspawn-oci/$2
rm -rf $umoci_output
umoci --verbose unpack --image $skopeo_output $umoci_output

mkdir -p /etc/systemd/nspawn
oci_config=$umoci_output/config.json
nspawn_config=/etc/systemd/nspawn/$2.nspawn

cat << end > $nspawn_config
[Exec]
ProcessTwo=true
end

for environment in $(jq --compact-output '.process.env' $oci_config | sed "s/[][]//g;s/\"//g;s/,/ /g")
do
echo $environment
cat << end >> $nspawn_config
Environment=$environment
end
done

cat << end >> $nspawn_config
WorkingDirectory=$(jq --compact-output '.process.cwd' $oci_config | sed "s/[][]//g;s/\"//g;s/,/ /g")
Parameters=$(jq --compact-output '.process.args' $oci_config | sed "s/[][]//g;s/,/ /g")
end

machinectl import-fs $umoci_output/rootfs $2
echo "$2 created from $1. start/enable via systemd-nspawn@$2.service"