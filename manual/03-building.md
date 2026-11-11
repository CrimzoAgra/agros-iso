# Building the ISO

Run the build from the repo's folder, with sudo:

```bash
sudo ./buildiso.sh -p desktop -v -w
```

The build gets half of the CPU at the lowest CPU and disk priority, so the PC stays cool, quiet and usable while it
runs. Add `-a` to give it all of the CPU: faster, but hotter and louder.

## A quick test build

```bash
sudo ./buildiso.sh -p desktop -v -w -f
```

`-f` compresses with zstd instead of xz. It's much faster and makes a bigger ISO. Use it to try out a change, and
build without it for a release.

## Options

```
$ ./buildiso.sh -h
Usage: buildiso.sh [options]
    -c                 Disable clean work dir
    -r                 Enable building in RAM on systems with more than 23GB RAM
    -w                 Remove build directory (not the ISO) after ISO file is built
    -f                 Fast test build: zstd instead of xz (much quicker, a bigger ISO)
    -a                 Use all of the CPU (by default the build gets half: cooler and quieter)
    -p <profile>       Buildset or profile [default: desktop]
    -v                 Verbose output to log file, show profile detail (-q)
    -h                 This help
```

- `-p desktop` is the only profile there is, and the default.
- Without `-c`, the build first deletes the work folder (`build/`) left by the last build.
- `-r` builds in a temporary folder in RAM, but only on a machine with more than 23 GB of RAM. Without `-w`, the build
  reminds you to delete that folder afterwards.
- `-w` deletes the work folder once the ISO is built. The ISO stays.

## What you get

Everything ends up in `out/desktop/`, named after the date (`YYMMDD`):

| File | What it is |
|---|---|
| `agros-desktop-linux-YYMMDD.iso` | The ISO |
| `agros-desktop-linux-YYMMDD.iso.sha1`, `.sha256` | Its checksums |
| `agros-desktop-linux-YYMMDD.iso.sig` | Its signature, if the signing key was found |
| `agros-desktop-linux-YYMMDD.pkgs.txt` | Every package on the live system, with its version |

### Checksums and signature

The build makes the checksums and the signature for the ISO it just built, not for the older ones in the folder.

It signs with the key set as `GPGKEY` in `~/.makepkg.conf` or `/etc/makepkg.conf`. With none set, it uses AgrOS's key,
`23B6096B42D05E1E`, the one AgrOS's packages are signed with. It looks for the key in the keyring of the user who ran
`sudo`, not root's. If the key isn't there, the build warns "Not signed" and finishes without a signature.

To check an ISO:

```bash
cd out/desktop
sha256sum -c agros-desktop-linux-YYMMDD.iso.sha256
gpg --verify agros-desktop-linux-YYMMDD.iso.sig agros-desktop-linux-YYMMDD.iso
```

## Put it on a USB stick

Use [balenaEtcher](https://etcher.balena.io), or `dd` (replace `sdX` with the stick; everything on it is erased):

```bash
sudo dd if=out/desktop/agros-desktop-linux-YYMMDD.iso of=/dev/sdX bs=4M status=progress
```

Then boot the computer from the stick. Installing is covered in AgrOS's manual:
[Installing](https://github.com/CrimzoAgra/agros/blob/main/manual/02-installing.md).

Next: [Testing it in a VM](04-testing.md)
