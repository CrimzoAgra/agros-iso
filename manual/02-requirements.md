# What you need

## A machine to build on

- Arch Linux or CachyOS.
- About 20 GB of free disk space: the work folder while it builds (removed after, with `-w`) and the ISO, about 3.5 GB each time. Building in RAM (`-r`) needs more than 23 GB of RAM.
- sudo rights: the build runs as root.
- The `[agros]` repo published, since the ISO's packages come from it.

## The packages

Refresh the package databases, then install the build tools:

```bash
sudo pacman -Syy
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub --needed
```

The ISO uses the same package signatures as the normal repos and has no mirrors package to install.

If `archiso` is missing when the build starts, `buildiso.sh` installs it with yay or trizen, if you have one of them.

## The code

```bash
git clone https://github.com/CrimzoAgra/agros-iso
cd agros-iso
```

## Optional

- **The AgrOS signing key** in your gpg keyring, to sign the ISO. Without it the build still works, the ISO is just
  unsigned. See [Building the ISO](03-building.md#checksums-and-signature).
- **VMware Workstation**, to test the ISO with `testiso.sh`. See [Testing it in a VM](04-testing.md).

Next: [Building the ISO](03-building.md)
