# NSpawn-OCI

Script to import OCI (Docker) containers to machined as nspawn containers

# Requirements

- systemd-machined
- systemd-nspawn
    - these are components of the monolithic systemd software. 
    Availibility and packaging of these components can vary wildy by distro.
    Refer to your distro's documentation.
- [skopeo](https://pkgs.org/download/skopeo)
- [umoci](https://pkgs.org/download/umoci)
- `--convert` requires [jq](https://pkgs.org/download/jq)

## Usage

This script was tested under Arch Linux. 
At the time of writing, this script's usage of `umoci` and `machinectl` require root access, so this script must be run as root.

```bash
import.sh $SOURCE $HOSTNAME [--convert|-c]
```

`$SOURCE` can be any supported [container transport](https://github.com/containers/image/blob/main/docs/containers-transports.5.md)

`$HOSTNAME` must be suitable for use as a hostname following a conservative subset of DNS and UNIX/Linux semantics.
See [machinectl documentation](https://www.freedesktop.org/software/systemd/man/machinectl.html#Machine%20and%20Image%20Names) for details.

`--convert` will read a subset of the OCI `config.json` and install an equivalent `.nspawn` file. If the container has empty mount ponts, you will be prompted for a bind point.

## How it works

### OCI mode

Below is a simplified version of the script containing the important lines.

```bash
# step 1: download the container to a temporary directory
skopeo copy "$source" oci:"$skopeo_output":latest
# step 2: convert the container to a format nspawn understands
umoci --verbose unpack --image "$skopeo_output" "$umoci_output" --keep-dirlinks
# step 3: override the default launch options for this container to use oci mode
cat << end > "$override"
[Service]
ExecStart=systemd-nspawn --oci-bundle=/var/lib/machines/%i --machine %i
end
# step 4: import the entire oci bundle
machinectl import-fs "$umoci_output" "$hostname"
```

### Convert mode

Instead of importing the entire OCI runtime bundle and creating an override in systemd for the relevant container, 
only the rootfs is imported and an [`.nspawn`](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html) file is generated from a few common options in the OCI `config.json`, namely:

- [Environment Variables](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html#Environment=)
- [Working Directory](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html#WorkingDirectory=)
- [Process Parameters](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html#Parameters=)
- [Bind Mounts](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html#Bind=)

Three additional options are added,
[`ProcessTwo=true`](https://www.freedesktop.org/software/systemd/man/systemd.nspawn.html#ProcessTwo=:~:text=the%20specified%20program%20is%20run%20as%20PID%202.%20A%20stub%20init%20process%20is%20run%20as%20PID%201),
[`VirtualEthernet=no`](https://wiki.archlinux.org/title/systemd-nspawn#Use_host_networking),
and `PrivateUsers=false`
