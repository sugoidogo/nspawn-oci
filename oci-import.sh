#!/usr/bin/env bash
set -euo pipefail

source=$1
hostname=$2
if [[ -v 3 ]];then
convert=true;else
convert=false;fi

cat << end
source=$source
hostname=$hostname
convert=$convert
end

workdir=/dev/shm/nspawn-oci
mkdir -p $workdir

skopeo_output=$(echo $workdir/$source | sed s.://./.g)
mkdir -p "$skopeo_output"
skopeo copy "$source" oci:"$skopeo_output":latest

umoci_output=$workdir/$hostname
rm -rf "$umoci_output"
umoci --verbose unpack --image "$skopeo_output" "$umoci_output" --keep-dirlinks

oci_config=$umoci_output/config.json

if $convert;then
# nspawn mode
mkdir -p /etc/systemd/nspawn
nspawn_config=/etc/systemd/nspawn/$hostname.nspawn

cat << end > "$nspawn_config"
[Exec]
ProcessTwo=true
end

for environment in $(jq --compact-output '.process.env' "$oci_config" | sed "s/[][]//g;s/\"//g;s/,/ /g")
do
echo "$environment"
cat << end >> "$nspawn_config"
Environment=$environment
end
done

cat << end >> "$nspawn_config"
WorkingDirectory=$(jq --compact-output '.process.cwd' "$oci_config" | sed "s/[][]//g;s/\"//g;s/,/ /g")
Parameters=$(jq --compact-output '.process.args' "$oci_config" | sed "s/[][]//g;s/,/ /g")

[Network]
VirtualEthernet=no

[Files]
end

for mount in $(jq -c '.mounts[]' "$oci_config"); do
source=$(echo "$mount" | jq -r '.source' )
echo "$source"
if [ "$source" == 'none' ]; then
echo 'container requires bind mount'
destination=$(echo "$mount" | jq -r '.destination')
read -p "$destination:" source
cat << end >> "$nspawn_config"
Bind=$source:$destination
end
fi
done

machinectl import-fs "$umoci_output"/rootfs $2
echo "Edit $nspawn_config before starting"

else
# oci mode
mkdir -p "/etc/systemd/system/systemd-nspawn@$hostname.service.d/"
override="/etc/systemd/system/systemd-nspawn@$hostname.service.d/override.conf"
cat << end > "$override"
[Service]
ExecStart=systemd-nspawn --oci-bundle=/var/lib/machines/%i --machine %i
end

machinectl import-fs "$umoci_output" "$hostname"
echo "Edit /var/lib/machines/$hostname/config.json before starting"

fi

cat << end
Start/Enable with systemd-nspawn@$hostname.service
$hostname created from $source
end