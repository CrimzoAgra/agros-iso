# AgrOS ISO

The installer ISO for [AgrOS](https://github.com/CrimzoAgra/agros): a fork of CachyOS's live ISO (Calamares, CachyOS's
kernels, its hardware detection). It's set up the way CachyOS sets up its own editions: AgrOS's repo, `[agros]`, is
in the live and installed systems' `pacman.conf`, and the installer's package list (`netinstall.yaml`) has one AgrOS
group, `agros-keyring` and `agros-desktop`, besides CachyOS's base. pacman installs exactly the final set of
packages; nothing is removed or built afterwards.

### What AgrOS changes here

- `archiso/pacman.conf`, `archiso/airootfs/etc/pacman.conf` and `pacman-more.conf` (the installed system's) get the
  `[agros]` repo; `packages_desktop.x86_64` gets `agros-keyring`, whose key the installer trusts
  (`calamares-online.sh`) and copies to the installed system.
- `archiso/airootfs/etc/calamares/modules/netinstall.yaml`: CachyOS's package list without the other desktops,
  Firefox, Alacritty, CachyOS Hello and CachyOS's fish settings, plus the AgrOS group.
- `archiso/airootfs/usr/local/bin/agros-calamares-config`, run when the installer starts, points the installer at that
  list, removes the desktop page, and makes CachyOS's own greetd step (`shellprocess@greetd`) start AgrOS's login
  screen.
- The ISO is named `agros`.

### Build

On Arch or CachyOS (about 3 GB of space; building in RAM needs more than 23 GB), once the `[agros]` repo is published:

```bash
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub --needed
sudo ./buildiso.sh -p desktop -v -w
```

The ISO appears in `out/`. Write it to a USB stick (balenaEtcher, or `sudo dd if=out/agros-*.iso of=/dev/sdX bs=4M
status=progress`) and boot it. The installer needs the internet (it downloads the packages).

To follow CachyOS's changes: `git pull upstream master` (upstream: `https://github.com/CachyOS/CachyOS-Live-ISO`).
When CachyOS changes its package list, update `netinstall.yaml` the same way.

---

CachyOS's original README follows.

These are the basic needed files and folders to build CachyOS system.

### buildiso

buildiso is used to build CachyOS ISO.

#### Arguments

~~~
$ ./buildiso.sh -h
Usage: buildiso [options]
    -c                 Disable clean work dir
    -r                 Disable building in RAM on systems with more than 23GB RAM
    -w                 Remove build directory (not the ISO) after ISO file is built
    -h                 This help
    -p <profile>       Buildset or profile [default: desktop]
    -v                 Verbose output to log file, show profile detail (-q)
~~~

* Uses the same signature that normal repo and has no mirrors package to install.

```bash
sudo pacman -Syy
```

### Install necessary packages:
```bash
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub --needed
```

### Clone:
```bash
git clone https://github.com/cachyos/cachyos-live-iso.git cachyos-archiso
cd cachyos-archiso
```

### Build
```bash
sudo ./buildiso.sh -p desktop -v -w
```

As the result iso appears at the `out` folder
