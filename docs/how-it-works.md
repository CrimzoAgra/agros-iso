<p align="center">
  <img src="images/agros-banner.svg" alt="AgrOS" width="320">
</p>

# How the AgrOS ISO works

The AgrOS ISO is CachyOS's live ISO ([CachyOS-Live-ISO](https://github.com/CachyOS/CachyOS-Live-ISO)) with as few
changes as it takes to install AgrOS. It's an [archiso](https://gitlab.archlinux.org/archlinux/archiso) profile
(`archiso/`) plus CachyOS's build scripts around `mkarchiso`. AgrOS itself, its packages and the repo they're published
in, lives in the [agros](https://github.com/CrimzoAgra/agros) repo; this one only builds the medium that installs it.

## The layout

| Path | What it is |
|---|---|
| `buildiso.sh` | The entry point: reads the options, sets up the work folder, runs the build |
| `util.sh` | Helpers: the timer, installing `archiso` if missing, checksums (`create_chksums`), signing (`sign_with_key`) |
| `util-iso.sh` | The build itself: `prepare_profile` and `run_build`, the console welcome, the ISO's file name |
| `util-iso-mount.sh` | Unmounts what a stopped build left mounted |
| `util-msg.sh` | Coloured messages and `import` |
| `upload-iso.sh` | Uploads a built ISO, with its `.sha256`, `.sig` and `.pkgs.txt`, to SourceForge (`buildiso.sh -u`, or by hand): see [Publishing the ISO](../manual/03-building.md#publishing-the-iso) |
| `agros.asc` | AgrOS's public signing key (packages and ISOs), for checking a downloaded ISO's `.sig` |
| `publish/` (`agros-iso-publish`, its service and timer, `install.sh`), `publish-iso.sh` | Publishes a new ISO by itself after each change on GitHub (agros-iso's `main`, or AgrOS's packages once CI passed): a root service builds GitHub's `main` in its own copy (`/var/lib/agros-iso-publish`) and uploads as you; `publish-iso.sh` checks now. See [Published by itself](../manual/03-building.md#published-by-itself) |
| `testiso.sh` | Boots the newest ISO in a VMware Workstation VM (made the first time; `--fresh` for a new empty disk) |
| `lddd.sh` | CachyOS's check for binaries with missing libraries |
| `archiso/profiledef.sh` | The profile: ISO name `agros`, label `AGROS_YYYYMM`, boot modes `bios.syslinux` and `uefi.grub`, squashfs with xz, file permissions |
| `archiso/packages_desktop.x86_64` | The live system's packages (copied to `packages.x86_64` at build time) |
| `archiso/pacman.conf` | The repos the live system is built from, `[agros]` included |
| `archiso/airootfs/` | Files copied onto the live system |
| `archiso/grub/` | The UEFI boot menu (`grub.cfg`, `loopback.cfg`) |
| `archiso/syslinux/` | The BIOS boot menu and its background (`splash.png`, the AgrOS banner) |
| `archiso/efiboot/` | systemd-boot entries, kept from CachyOS; unused while the profile boots UEFI with GRUB |
| `CHANGELOG.md` | CachyOS's release notes |

### The live system's files

The AgrOS ones in `archiso/airootfs/`:

| Path | What it does |
|---|---|
| `etc/pacman.conf`, `etc/pacman-more.conf` | The live system's and the installed system's `pacman.conf`, both with `[agros]` |
| `etc/greetd/config.toml` | Logs `liveuser` straight into Hyprland (`uwsm start -e -D Hyprland hyprland.desktop`); logged out, `agreety` starts it again |
| `etc/xdg/autostart/agros-install.desktop` | Opens the installer when the session starts |
| `etc/xdg/autostart/live-session-menu.desktop` | Runs `live-session-menu` when the session starts |
| `home/liveuser/.config/quickshell/sidedock/pins.json` | An empty list: no pinned apps in the dock |
| `usr/share/applications/agros-install.desktop` | **Install AgrOS** in the Super menu; its `StartupWMClass` gives the installer's window AgrOS's icon in the dock |
| `usr/local/bin/calamares-online.sh` | Starts the installer (below) |
| `usr/local/bin/agros-calamares-config` | AgrOS's installer settings (below) |
| `usr/local/bin/live-session-menu` | Sets Caelestia's `launcher.hiddenApps` in the live user's `shell.json` to hide every app but `agros-install`, `foot`, `thunar`, `librewolf` and `gparted` (with `jq`, under the lock the file's other writers use) |
| `usr/local/bin/pkexec-wrapper` | Runs the installer as root under Hyprland (below) |
| `usr/share/agros/netinstall.yaml` | The installer's package list |
| `usr/share/calamares/branding/agros/` | The installer's branding (below) |

## A build, step by step

`sudo ./buildiso.sh -p desktop -v -w` runs these, in order:

1. **Options.** `-c`, `-r`, `-w`, `-f`, `-a`, `-u`, `-p`, `-v` and `-h`, as in [Building the ISO](../manual/03-building.md).
   The work folder is `build/` (with `-r` and more than 23 GB of RAM, a `mktemp` folder in RAM); the output is
   `out/`. If `archiso` isn't installed, `check_requirements` installs it with yay or trizen.
2. **`prepare_profile`** writes the generated files into `archiso/` (they're in `.gitignore`): the date as the
   version in `etc/version-tag` (and in the work copy's `grub.cfg` and `loopback.cfg`, `CACHYOS_VERSION`, once copied:
   the repo's say `GIT`); CachyOS's current mirrorlist (the build stops if it can't be downloaded), from
   CachyOS-PKGBUILDS; a mask for `cachyos-rate-mirrors.timer`; the console welcome (`etc/motd`, AgrOS's); the
   `display-manager.service` link to greetd; `packages.x86_64`; `etc/environment` (`ZPOOL_VDEV_NAME_PATH=1`); and
   `etc/edition-tag` (`desktop`). Any profile but `desktop` stops the build.
3. **`run_build`** deletes the old work folder (not with `-c`) and copies `archiso/` into it. With `-f`, it switches
   the copy's squashfs (`profiledef.sh`) and initramfs (`archiso.conf`) compression from xz to zstd, so the
   repo's profile stays as it is.
4. **mkarchiso changes.** The build patches the system's `/usr/bin/mkarchiso` once, so the ISO doesn't ship Arch's
   `archlinux-keyring-wkd-sync.timer`, and its package list is read from the ISO's package database with no repos
   set (through the live system's own pacman.conf it warned that the keyring, made at boot, isn't there yet). With
   `-v` it also sets mkarchiso's `quiet="n"`. These edits stay until `archiso` is reinstalled.
5. **mkarchiso** builds the ISO into `out/desktop/`, through
   `systemd-run --scope -p CPUQuota=...% nice -n 19 ionice -c 3`. The quota is half of the CPU (`nproc` x 50 %), or
   all of it with `-a`: every core flat out for the whole build ran the CPU at 86 °C with the fan at full.
6. **Naming.** mkarchiso's `agros-YYYY.MM.DD-x86_64.iso` (whatever its date: a build that ran past midnight, or a
   work folder kept by `-c`) is renamed to `agros-desktop-linux-YYMMDD.iso` (`gen_iso_fn`), and the live system's package list is copied next to it as `.pkgs.txt`.
7. **Checksums and signature** for that ISO only: `.sha1` and `.sha256`, then a detached `.sig`. `sign_with_key`
   takes `GPGKEY` from `~/.config/pacman/makepkg.conf`, `~/.makepkg.conf` (the home of whoever ran it, under sudo too) or `/etc/makepkg.conf`, or else AgrOS's key `23B6096B42D05E1E` (the one
   `agros-keyring` holds), and signs as `$SUDO_USER` with that user's keyring. Without the key it warns and skips
   the signature. Signing each build's ISO alone, not every ISO in the folder again, is an AgrOS change.
8. **Cleanup.** With `-w` it deletes the work folder. The exit trap, there to report a build that stops halfway, is
   cleared at the end, so a good build no longer ends with "An unknown error has occurred".
9. **Upload**, with `-u` only: `upload-iso.sh` on the ISO just built. Run as root, it starts itself again as
   `$SUDO_USER` (`sudo -u "$SUDO_USER" -H`), so ssh, gpg and `~/.config/agros-iso/upload.conf` are that user's. It
   checks the `.sha256` and the `.sig`, then copies the files to SourceForge's file release system with rsync (or scp),
   and with `SF_API_KEY` set makes the ISO the default download through SourceForge's API.

## What AgrOS changes from CachyOS's ISO

- `archiso/pacman.conf`, `archiso/airootfs/etc/pacman.conf` and `pacman-more.conf` (the installed system's) get the
  `[agros]` repo; `packages_desktop.x86_64` gets `agros-keyring`, whose key the installer trusts
  (`calamares-online.sh`) and copies to the installed system.
- `archiso/airootfs/usr/share/agros/netinstall.yaml`: CachyOS's package list without the other desktops, Firefox,
  Alacritty, CachyOS Hello and CachyOS's fish settings, plus the AgrOS group (hidden, selected and critical:
  `agros-keyring` and `agros-desktop`). It's in `/usr/share/agros` because the installer package owns
  `/etc/calamares/modules/netinstall.yaml`.
- `archiso/airootfs/usr/local/bin/agros-calamares-config`, run when the installer starts, points the installer at that
  list, removes the desktop page, and makes CachyOS's own greetd step (`shellprocess@greetd`) start AgrOS's login
  screen.
- `calamares-online.sh` installs the installer from `[agros]`: AgrOS rebuilds CachyOS's against the current libraries,
  because CachyOS's own can lag behind an Arch update and not start.
- The live session is AgrOS's own desktop, not CachyOS's KDE: `packages_desktop.x86_64` has Hyprland, Caelestia and
  AgrOS's settings instead of Plasma (the big apps of `agros-desktop` only go on the installed system), and greetd logs
  the live user straight into it (`airootfs/etc/greetd/config.toml`, enabled by `util-iso.sh`). CachyOS's Plasma
  login and KDE settings in `etc/skel` are gone. The installer opens when the session starts, and is "Install AgrOS"
  in the app menu. The menu and dock are cut down to what installing needs (`live-session-menu`, the empty
  `pins.json`).
- The installer is AgrOS's: its branding (`airootfs/usr/share/calamares/branding/agros`: the name, the logo and name as
  in AgrOS's README, its colours), AgrOS in its steps, the suggested computer name (`agros-...`) and the firmware's
  boot entry (`AgrOS`).
- The boot menus say AgrOS (GRUB, the BIOS menu and the unused systemd-boot entries; the kernel's own files keep their
  names). The BIOS menu's background is the AgrOS banner and its title is in the logo's colour (`#bec4ee`).
- The ISO is named `agros`, and its console welcome (`util-iso.sh`'s motd) is AgrOS's.
- The build: `-f`, `-a`, `-u` (upload to SourceForge), the low priority and half-CPU default, the per-ISO checksums and signature with AgrOS's key,
  and no "unknown error" after a good build.

## The installer

### Starting it

`calamares-online.sh` (CachyOS's, with AgrOS's lines):

1. Resets the pacman keyring, installs the latest `archlinux-keyring` and `cachyos-keyring`, and populates the
   `archlinux`, `cachyos` and `agros` keys. It syncs the clock too, since a keyring "created in the future" breaks
   the install.
2. Installs `agros/cachyos-calamares-next`, AgrOS's rebuild of the installer.
3. Writes the hardware (`inxi -F`) and the ISO's version into `/home/liveuser/cachy-install.log`.
4. Copies CachyOS's `settings_online.conf` to `/etc/calamares/settings.conf` and runs `agros-calamares-config`.
5. Starts `calamares -D6` through `pkexec-wrapper`, logging into the same file.

`pkexec-wrapper` hands root's Calamares the Wayland socket by its full path, so it reaches the live session's Hyprland
without getting the user's `XDG_RUNTIME_DIR` (root's files there would belong to root). KDE's session fell back to X;
Hyprland's has no X authority for root. It sets `QT_QUICK_BACKEND=software`: drawn by the GPU, root's Calamares lost its
Wayland connection a second after opening (Hyprland: "unknown object, message attach"; seen in VMware). It passes the
desktop's Qt theme (`QT_QPA_PLATFORMTHEME`, qtengine with the user's colours), because Calamares draws some parts, such
as the partition names, from the palette and not the stylesheet.

### AgrOS's settings

`agros-calamares-config` edits CachyOS's settings in `/etc/calamares` after `calamares-online.sh` has put them there:

- `netinstall.conf`: the package list from
  `https://raw.githubusercontent.com/CrimzoAgra/agros-iso/main/archiso/airootfs/usr/share/agros/netinstall.yaml`
  first, and the ISO's own copy (`file:///usr/share/agros/netinstall.yaml`) if that can't be fetched. So a change to
  `netinstall.yaml` pushed to `main` reaches ISOs that are already built.
- `shellprocess_greetd.conf` (the install's last step, in the new system): removes the six `.pacnew` files of the
  live system's pacman.conf, resolv.conf and mirror lists; deletes the snapshots the install's own package runs made
  (the boot menu's list starts with the installation's alone); runs agros-boot's `boot-menu` and `splash-theme` now
  that GRUB is set up (agros-boot's own install runs before `/boot/grub` exists, and the `grubcfg` and `plymouthcfg`
  steps set CachyOS's after it); removes CachyOS's unused `remove-nvidia`; and last, copies `caelestia-greeter`'s greetd
  config into place and enables greetd (CachyOS's `dmcheck` only enables greetd for `noctalia-greeter`, so without
  this AgrOS would boot to a text login). It also names the first snapshot "Fresh AgrOS Installation", and has the
  btrfs step that takes it (after this one) remake GRUB's menu, so the snapshot is in it from the first boot.
- `branding: agros` in `settings.conf`; AgrOS in place of CachyOS in the names of the `shellprocess-before` steps;
  `agros-${cpu}` as the suggested computer name (`users.conf`); `efiBootloaderId: "AgrOS"` (`bootloader.conf`), the
  firmware's boot entry and GRUB's folder `EFI/AgrOS`.
- Removes `packagechooser@desktop`, and fails if it's still there.
- GRUB only, with no bootloader page (AgrOS's hidden boot menu, its theme and the snapshots in it are GRUB's): removes
  `packagechooser@bootloader`, whose choice (Limine by default) the rest of the installer reads. So the `bootloader`
  step is set to GRUB (`efiBootLoader: "grub"`, its `efiBootLoaderVar` removed: with it and no page, no bootloader was
  installed), `pacstrap` and `grubcfg` (their `main.py`) take GRUB when nothing was chosen, and the partition page
  starts on GRUB's settings (`partition.conf`: the boot partition at `/boot/efi`, 512 MB, as CachyOS's GRUB override
  has it). Fails if any of these didn't apply.

### The branding

`usr/share/calamares/branding/agros/`:

| File | What it is |
|---|---|
| `branding.desc` | The names, URLs (AgrOS's repo and issues), images and sidebar colours; a 1100x520 window, the step bar at the bottom (`sidebar: qml,bottom`) |
| `stylesheet.qss` | The desktop's dark scheme (primary `#bec4ee`), Rubik like the shell, pill buttons and fields, rounded panels, styled check boxes, drop-downs and the package list's highlight |
| `calamares-sidebar.qml` | The step bar: pills, clickable back to any step and forward as far as reached (through Back and Next, so each page's checks apply), the steps not reached yet greyed |
| `LoadingLogo.qml`, `show.qml` | The install page's slideshow: the logo's leaves drawn from the centre out and gone the same way |
| `logo.png`, `icon.png`, `welcome.png` | The logo, the window icon and the welcome page's picture |
| `*.svg` | The check mark, drop-down arrow and tree branches the stylesheet uses |

## How the [agros] repo fits in

The ISO builds nothing of AgrOS's itself. Everything AgrOS comes from the `[agros]` repo
(`https://crimzoagra.github.io/agros/$arch`), which the agros repo's CI (`ci/build-repo.sh`) builds and publishes on
GitHub Pages, signed with AgrOS's key:

- **AgrOS's packages.** The live system gets `agros-keyring`, `agros-scripts`, `agros-hyprland-settings` and
  `agros-welcome`, plus the AUR packages AgrOS builds into the repo (`quickshell-git`, `caelestia-shell`, ...). The
  installed system gets `agros-desktop` and everything it pulls in.
- **The installer.** The CI rebuilds CachyOS's `cachyos-calamares` PKGBUILD against today's libraries. CachyOS's own
  build was made for Boost 1.91 and didn't start once Arch moved to 1.92. The rebuild's `pkgrel` is CachyOS's plus
  `.5`; the ISO's package list names it `agros/cachyos-calamares-next` (pacman takes a package from the first repo
  that has it, `[cachyos]`, not the newest), and it carries small fixes for AgrOS's dark theme: the partition names in the theme's
  text colours, the package list's highlight cleared on a click on no row, and the language list's English names
  readable on the highlighted row; and GRUB only: where its compiled modules read the bootloader page's choice (the
  ZFS pool's GRUB compatibility, the partition page's GRUB settings, its BIOS hint, the boot partition on erase-disk),
  GRUB, as `agros-calamares-config` does for the Python ones. `calamares-online.sh` installs it from `[agros]` each time the installer starts,
  so an ISO picks up a newer rebuild without being built again.

So the repo has to be published before you build: the build's pacman reads it, and so does the installer.

## Following CachyOS

`upstream` is `https://github.com/CachyOS/CachyOS-Live-ISO`. To take in CachyOS's changes:

```bash
git pull upstream master
```

When CachyOS changes its package list, update `netinstall.yaml` the same way. After a new CachyOS installer, check the
Partitions and Packages pages and the language list: the installer's fixes are plain text swaps in the agros repo's CI,
and an upstream rewrite undoes them without anything failing.

## Credits

- [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO): the profile, scripts, installer setup and hardware
  detection this repo is a fork of.
- [archiso](https://gitlab.archlinux.org/archlinux/archiso): Arch's ISO builder.
- [Calamares](https://github.com/calamares/calamares): the installer.

The repo is released under the GPL-3.0 (`LICENSE`).
