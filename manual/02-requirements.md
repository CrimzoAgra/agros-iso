# What you need

## A machine to build on

- Arch Linux or CachyOS.
- About 20 GB of free disk space: the work folder while it builds (removed after, with `-w`), the ISO, about 3.6 GB
  each time, and the packages pacman downloads for it, about 3-4 GB, kept in `/var/cache/pacman/pkg`. Building in RAM
  (`-r`) needs 14 GB free in `/tmp`, a tmpfs in RAM: by default it can grow to half the RAM, so about 32 GB of RAM.
- sudo rights: the build runs as root.
- The `[agros]` repo published, since the ISO's packages come from it.

## The packages

Refresh the package databases, then install git, to get the code:

```bash
sudo pacman -Syy
sudo pacman -S git --needed
```

The profile's `pacman.conf` names CachyOS's and AgrOS's servers itself, so there's no mirrors package to install; their
keys are needed, below.

The build tools (`archiso`, `git`, `grub`) `buildiso.sh` installs itself with pacman when it starts, those that are
missing, or it stops with the command to run.

## The code

```bash
git clone https://github.com/CrimzoAgra/agros-iso
cd agros-iso
```

## The package keys

The build's pacman checks every package with your system's keyring, so it has to trust the keys of CachyOS's and
AgrOS's repos (GitHub's build does the same, in `.github/workflows/iso.yml`):

- **CachyOS's key**: there already on CachyOS (`cachyos-keyring`). On plain Arch, trust it by its full fingerprint:

  ```bash
  sudo pacman-key --recv-keys 882DCFE48E2051D48E2562ABF3B607488DB35A47 --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 882DCFE48E2051D48E2562ABF3B607488DB35A47
  ```

- **AgrOS's key**: there already where `agros-keyring` is installed (on AgrOS). Otherwise, from the repo's folder:

  ```bash
  sudo pacman-key --add agros.asc
  sudo pacman-key --lsign-key BFE9289F7759E521AE60CFCD23B6096B42D05E1E   # agros.asc's fingerprint
  ```

## Optional

- **The AgrOS signing key** in your gpg keyring, to sign the ISO. Without it the build still works, the ISO is just
  unsigned. See [Building the ISO](03-building.md#checksums-and-signature).
- **VMware Workstation**, to test the ISO with `testiso.sh`. See [Testing it in a VM](04-testing.md).

Next: [Building the ISO](03-building.md)
