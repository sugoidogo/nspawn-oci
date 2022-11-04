# NSpawn-OCI
Script to import OCI (Docker) containers to systemd-nspawn
## Usage
```bash
import.sh $SOURCE $HOSTNAME [--convert|-c]
```
`$SOURCE` can be any supported [container transport](https://github.com/containers/image/blob/main/docs/containers-transports.5.md)

`$HOSTNAME` may consist of only letters, digits, and the hyphen (`-`) symbol, and has a maximum length of 15 characters.

`--convert` will attempt to convert the container from OCI to nspawn with the following caveats:
- the nspawn container uses host networking. If you wish to use bridged or nat, there are many ways to do so, and you will need to decide for yourself.
- a small subset of common options are converted, including:
    1. Environment Variables
    2. Working Directory
    3. Process Parameters
    4. Bind Mounts
        - when a container has declared a mount point, you will be prompted for the host bind point

After importing, you may need to edit either `config.json` or `name.nspawn`. The appropriate config path will be printed at the end of the script. Keep in mind when using converted containers that guest networking is likely to be completely unconfigured, so if you want to change from host networking mode to use port mapping or bridge networking you will need to configure both a bridge interface on the host and guest networking inside each container.