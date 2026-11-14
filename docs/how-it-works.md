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
| `util.sh` | Helpers: the timer, the build's requirements (`check_requirements`), checksums (`create_chksums`), signing (`sign_with_key`) and checking a signature is AgrOS's (`verify_agros_sig`), a key file's fingerprint (`key_fpr`), the output folder (`iso_out_dir`, `out/desktop`) and the newest ISO in it (`newest_iso`), the user who ran `sudo` (`invoking_user`, `as_invoking_user`); also used by `upload-iso.sh`, `testiso.sh` and the ISO workflow |
| `util-iso.sh` | The build itself: `prepare_profile` and `run_build`, the console welcome, the ISO's file name |
| `util-iso-mount.sh` | Unmounts what a stopped build left mounted |
| `util-msg.sh` | Coloured messages (`msg`, `warning`, `error`, `die`; on GitHub, warnings and errors are also annotations on the run) and `import`; also used by `upload-iso.sh` and `testiso.sh` |
| `upload-iso.sh` | Uploads a built ISO, with its `.sha256`, `.sig` and `.pkgs.txt`, to SourceForge (`buildiso.sh -u`, or by hand): see [Publishing the ISO](../manual/03-building.md#publishing-the-iso) |
| `agros.asc` | AgrOS's public signing key (packages and ISOs), for checking a downloaded ISO's `.sig` |
| `.github/workflows/iso.yml` | GitHub publishes a new ISO after each change: a push of `main` (not one of only docs), or AgrOS's packages changed (agros's CI starts it after publishing them); built, signed and uploaded there. See [Published by itself](../manual/03-building.md#published-by-itself) |
| `testiso.sh` | Boots the newest ISO in a VMware Workstation VM (made the first time; `--fresh` for a new empty disk) |
| `archiso/profiledef.sh` | The profile: ISO name `agros`, label `AGROS_YYYYMM`, boot modes `bios.syslinux` and `uefi.grub`, squashfs with zstd (level 15), file permissions |
| `archiso/packages_desktop.x86_64` | The live system's packages (copied to `packages.x86_64` in the build's copy of the profile) |
| `archiso/pacman.conf` | The repos the live system is built from, `[agros]` included |
| `archiso/airootfs/` | Files copied onto the live system |
| `archiso/grub/` | The UEFI boot menu (`grub.cfg`, `loopback.cfg`) |
| `archiso/syslinux/` | The BIOS boot menu and its background (`splash.png`, the AgrOS banner) |
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
| `etc/pacman.d/hooks/agros-live-rate-mirrors-off.hook` | Turns `cachyos-rate-mirrors.timer` off on the live system once its package has enabled it (only for the build: removed afterwards, as CachyOS's build-time hooks are) |
| `usr/share/agros/netinstall.yaml` | The installer's package list |
| `usr/share/calamares/branding/agros/` | The installer's branding (below) |

## A build, step by step

`sudo ./buildiso.sh -p desktop -w` runs these, in order:

1. **Options.** `-c`, `-r`, `-w`, `-f`, `-a`, `-u`, `-p` and `-h`, as in [Building the ISO](../manual/03-building.md);
   any other, or an argument, stops it. The work folder is `build/` (with `-r`, a `mktemp` folder in `/tmp`, RAM, if it
   has 14 GB free: the live system unpacked, about 7.6 GB, and the ISO's files with its squashfs, about 3.3 GB); the
   output is `out/desktop/` (`iso_out_dir`). `check_requirements` installs what the build needs on the host and is
   missing (`archiso`, `git`, `grub`: the one list of them; `squashfs-tools` comes with `archiso`, and
   `mkinitcpio-archiso` goes into the ISO from its package list) with `sudo pacman -S`, or stops with the command to
   run. It also stops when `pacman -Qkk archiso` finds `/usr/bin/mkarchiso` edited (older checkouts
   edited it in place), with the command that restores it.
2. **`run_build`** deletes the old work folder (not with `-c`, which resumes a stopped build; `buildiso.sh` refuses it
   when the folder has mkarchiso's last marker, `iso._build_iso_image`) and copies `archiso/` into it: only the files
   git tracks (`copy_profile`, `git ls-files`; edits not committed yet included), so what an older checkout's build
   left in `archiso/` (root's generated files) never reaches the ISO. Files git doesn't track (and .gitignore doesn't
   name) are listed with a warning (`git add` a new one to have it in). Not a git checkout (a download of the repo):
   all of `archiso/`, with a warning.
3. **`prepare_profile`** takes the build's time once (the version and the ISO's name below are the same moment) and
   writes the generated files into that copy, so the repo's profile stays as it is: the date as the version in
   `etc/version-tag` (and in `grub.cfg` and `loopback.cfg`, `CACHYOS_VERSION`, checked in both: the repo's say `GIT`);
   CachyOS's current mirrorlist (the build stops if it can't be downloaded), from CachyOS-PKGBUILDS; the console
   welcome (`etc/motd`, AgrOS's); the `display-manager.service` link to greetd; `packages.x86_64`; `etc/environment`
   (`ZPOOL_VDEV_NAME_PATH=1`); and `etc/edition-tag` (`desktop`). Any profile but `desktop` stops the build at once
   (`buildiso.sh`, right after its options), before anything is deleted or downloaded. With
   `-f`, it lowers the copy's squashfs zstd level (`profiledef.sh`) from 15 to 6, and stops if that line didn't change.
4. **mkarchiso changes.** `modify_mkarchiso` copies the system's `/usr/bin/mkarchiso` to the work folder (`mkarchiso`)
   and edits the copy, which the build runs; Arch's own isn't touched (older checkouts edited it in place: see
   [Troubleshooting](../manual/06-troubleshooting.md)). The edits: the ISO doesn't ship Arch's
   `archlinux-keyring-wkd-sync.timer`, and its package list is read from the ISO's package database with no repos set
   (through the live system's own pacman.conf it warned that the keyring, made at boot, isn't there yet). Each edit is
   checked, so an archiso update that moves a line stops the build. mkarchiso always shows its whole output. It runs as
   root (through sudo), so it warns "Running as root is not advised".
5. **mkarchiso** builds the ISO into `out/desktop/`, through `nice -n 19 ionice -c 3`, and on half of the CPU
   (`systemd-run --scope -p CPUQuota=`, `nproc` x 50 %): every core flat out for the whole build ran the CPU at 86 °C
   with the fan at full. No quota with `-a`, or with no systemd running (GitHub's container).
6. **Naming.** mkarchiso's `agros-YYYY.MM.DD-x86_64.iso` (whatever its date: a build that ran past midnight, or a work
   folder kept by `-c`) is renamed to `agros-desktop-linux-YYMMDD-HHMM.iso` (`gen_iso_fn`; the time too, so two the same
   day don't share a name), and the live system's package list is copied next to it as `.pkgs.txt`.
7. **Checksums and signature** for that ISO only: `.sha1` and `.sha256`, then a detached `.sig`. `sign_with_key` signs
   with AgrOS's key, the one in `agros.asc` (`23B6096B42D05E1E`, the one `agros-keyring` holds; read from the file, as
   the ISO workflow does for its pacman keyring), always: a `GPGKEY` in a `makepkg.conf` isn't read, since the upload
   refuses a signature by any other key. It signs as the user who ran `sudo` (`as_invoking_user`), with their keyring.
   Without the key, or when gpg fails (no passphrase, pinentry or primary key), it warns and skips the signature; the
   cleanup and upload still run. Signing each build's ISO alone, not every ISO in the folder again, is an AgrOS
   change.
8. **Cleanup.** With `-w` it deletes the work folder. The exit trap, there to report a build that stops halfway, is
   cleared at the end, so a good build no longer ends with "An unknown error has occurred". A build that stops says
   why once (its own error, or "An unknown error has occurred" for a failed command), unmounts once, and with `-r`
   says where the work folder is, still in RAM.
9. **Upload**, with `-u` only: `upload-iso.sh` on the ISO just built. Run as root, it starts itself again as the
   user who ran `sudo` (`as_invoking_user`: `sudo -u "$SUDO_USER" -H`), so ssh and `~/.config/agros-iso/upload.conf`
   are that user's. It refuses (exit code 65) an ISO that doesn't match its `.sha256`, or whose `.sig` isn't a good
   signature by AgrOS's key: `verify_agros_sig` checks it with `gpgv` against a keyring of `agros.asc` alone (not the
   user's keyring, so no other key passes) and matches the `VALIDSIG` fingerprint with `agros.asc`'s. An ISO with no
   `.sig` goes up with a warning (`buildiso.sh -u`); with `--signed`, as the ISO workflow uses it, it's refused too.
   Then it copies the files to SourceForge's file release system with rsync (or scp), and with `SF_API_KEY` set makes
   the ISO the default download through SourceForge's API. The ISO workflow tries the upload 3 times, but not after a
   refusal.

## What AgrOS changes from CachyOS's ISO

- `archiso/pacman.conf`, `archiso/airootfs/etc/pacman.conf` and `pacman-more.conf` (the installed system's) get the
  `[agros]` repo; `packages_desktop.x86_64` gets `agros-keyring`, whose key the installer trusts
  (`calamares-online.sh`) and copies to the installed system.
- `archiso/airootfs/usr/share/agros/netinstall.yaml`: CachyOS's package list (the installer package's
  `/etc/calamares/modules/netinstall.yaml`) plus the AgrOS group (hidden, selected and critical: `agros-keyring` and
  `agros-desktop`). It's in `/usr/share/agros` because the installer package owns CachyOS's. What's different, and why:
  - No other desktops or window managers (KDE, GNOME, Cosmic, Niri, Cinnamon, Budgie, MATE, Xfce, LXQt, LXDE,
    CachyOS's Hyprland, MangoWM, Sway, Wayfire, i3, Qtile, bspwm, Openbox): `agros-desktop` is the desktop.
  - No **CachyOS Handhelds** group: its `cachyos-handheld` brings Plasma's login manager and Steam's gamescope session,
    a second login screen and desktop next to AgrOS's (the hidden handheld kernels group stays).
  - No **Support for HP Printer/Scanner** group (unticked by CachyOS): `agros-desktop` has CUPS and HPLIP already.
  - No **Firefox and language package** (`agros-desktop` has LibreWolf), Alacritty (AgrOS's terminal is foot),
    `cachyos-hello` (AgrOS has `agros-welcome`), `cachyos-fish-config` and `cachyos-micro-settings`
    (`agros-hyprland-settings` has AgrOS's own fish and micro settings in `/etc/skel`, and replaces them).
  - `pipewire-jack` added: with nothing named for JACK, `pacman --noconfirm` picked `jack2`, which conflicts.
- `archiso/airootfs/usr/local/bin/agros-calamares-config`, run when the installer starts, points the installer at that
  list, removes the desktop page, and makes CachyOS's greetd step (`shellprocess@greetd`) start AgrOS's login
  screen, adding the step where CachyOS's settings don't have it (its newer branches).
- The live system is named AgrOS: `airootfs/etc/os-release` (`NAME`, `PRETTY_NAME`, `LOGO=agros-logo`) and
  `airootfs/etc/hostname` (`agros`).
- The network-boot (PXE) menu entries drop `cms_verify=y` (`archiso/syslinux/archiso_pxe-linux.cfg`, the reason in a
  comment there).
- The live system's installer is AgrOS's rebuild from `[agros]` (`agros/cachyos-calamares-next` in
  `packages_desktop.x86_64`): CachyOS's own can lag behind an Arch update and not start.
- The live session is AgrOS's own desktop, not CachyOS's KDE: `packages_desktop.x86_64` has Hyprland, Caelestia and
  AgrOS's settings instead of Plasma (the big apps of `agros-desktop` only go on the installed system), and greetd logs
  the live user straight into it (`airootfs/etc/greetd/config.toml`, enabled by `util-iso.sh`). CachyOS's Plasma
  login and KDE settings in `etc/skel` are gone. The installer opens when the session starts, and is "Install AgrOS"
  in the app menu. The menu and dock are cut down to what installing needs (`live-session-menu`, the empty
  `pins.json`).
- The installer is AgrOS's: its branding (`airootfs/usr/share/calamares/branding/agros`: the name, the logo and name as
  in AgrOS's README, its colours), AgrOS in its steps, the suggested computer name (`agros-...`) and the firmware's
  boot entry (`AgrOS`).
- The boot menus say AgrOS (GRUB and the BIOS menu; the kernel's own files keep their names). CachyOS's unused
  systemd-boot entries (`efiboot/`), its `remove-nvidia` (and so out of the files the installer copies to the new
  system, below) and its `linux.preset` (for Arch's `linux`, not on the ISO:
  it only built the LTS kernel's initramfs a second time; each kernel's own preset uses the `archiso.conf` drop-in)
  are gone. The BIOS menu's background is the AgrOS banner and its title is in the logo's colour (`#bec4ee`).
- No boot text on the menus' normal entries (GRUB's `grub.cfg` and `loopback.cfg`, syslinux's BIOS and PXE ones):
  `quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false`, the list an installed AgrOS gets from agros's
  `system/boot-video-mode` (`QUIET`, the one list), less `splash` (there's no Plymouth on the live ISO). The Legacy
  Hardware / Fallback (nomodeset) entries keep the text, for troubleshooting.
- The live system's `pacman.conf` checks `[cachyos]`'s signatures as every other repo's (CachyOS's
  `SigLevel = Optional TrustAll` for it is gone; its key is in the keyring `pacman-init.service` makes at boot).
- Gone from the live system, unused or replaced by AgrOS's own: `etc/hosts` (it pinned `raw.githubusercontent.com` to
  one fixed IP); the text console's autologin (`getty@tty1.service.d/autologin.conf`, root's `.zlogin` and
  `.automated_script.sh`, archiso's `script=` boot option runner, and the `autologin` group: greetd logs the live user
  in); the KWin keyboard-layout hook (`90-cachyos-live-kwin-keyboard.hook`, for Plasma's `cachyos-kde-settings`);
  `usr/local/share/livecd-sound`; `etc-pacman.d-gnupg.mount` (nothing used it: the ISO's `pacman-init.service` doesn't
  require it); `bootstrap_packages.x86_64` (only for archiso's bootstrap build mode, not `iso`); and the `linux-atm`
  package (ADSL modems' ATM tools).
- The ISO is named `agros`, and its console welcome (`util-iso.sh`'s motd) is AgrOS's.
- The build: `-f`, `-a`, `-u` (upload to SourceForge), the low priority and half-CPU default, the per-ISO checksums and
  signature with AgrOS's key, only git's tracked files of the profile, and no "unknown error" after a good build.

## The installer

### Starting it

`calamares-online.sh` (CachyOS's, with AgrOS's lines):

1. Stops if it's already running (a lock in `$XDG_RUNTIME_DIR`, held until the installer closes), so opening it
   again from the menu doesn't start a second one.
2. Waits for the internet (`nmcli networking connectivity check`: `full`). Not connected, as on Wi-Fi at the first
   login, it says "Connect to the internet to install" once in a notification and checks every 2 seconds, for up to 5
   minutes; then it goes on either way (the keyring step below fails, with its notification, if still offline).
   Syncs the clock and waits for it (up to 30 seconds), since a keyring "created in the future" breaks the install.
   Waits for the ISO's `pacman-init.service` (the keyring it makes at boot), then makes a new pacman keyring and
   populates the `archlinux`, `cachyos` and `agros` keys, then installs the latest `archlinux-keyring` and
   `cachyos-keyring`. The installer itself isn't installed again: the ISO's is AgrOS's rebuild, and installed from
   `[agros]` on a live system it could be one built against newer libraries than the ISO has. A new ISO is built
   after each change to what goes into it instead. If any of the keyring steps fails, it stops there with a
   notification, before anything is changed on the disks (as it does when `agros-calamares-config` fails).
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
- `shellprocess_greetd.conf` (one of the install's last steps, in the new system: after the bootloader and the
  services, before the installation snapshot and the cleanup): removes the six `.pacnew` files of the
  live system's pacman.conf, resolv.conf and mirror lists; deletes the snapshots the install's own package runs made
  (the boot menu's list starts with the installation's alone); runs agros-boot's `boot-menu` and `splash-theme` now
  that GRUB is set up (agros-boot's own install runs before `/boot/grub` exists, and the `grubcfg` and `plymouthcfg`
  steps set CachyOS's after it; on an AMD GPU `splash-theme` keeps the plain `cachyos` theme CachyOS's `plymouthcfg`
  picks there, as its animated one breaks on some AMD GPUs); and last, copies `caelestia-greeter`'s greetd
  config into place and enables greetd (CachyOS's `dmcheck` only enables greetd for `noctalia-greeter`, so without
  this AgrOS would boot to a text login). It also names the first snapshot "Fresh AgrOS Installation", and has the
  btrfs step that takes it (after this one) remake GRUB's menu, so the snapshot is in it from the first boot.
- `branding: agros` in `settings.conf`; AgrOS in place of CachyOS in the names of the `shellprocess-before` steps;
  `agros-${cpu}` as the suggested computer name (`users.conf`); `efiBootloaderId: "AgrOS"` (`bootloader.conf`), the
  firmware's boot entry and GRUB's folder `EFI/AgrOS`; and `/usr/local/bin/remove-nvidia` out of `pacstrap.conf`'s
  `postInstallFiles` (not on the ISO: each install logged "Failed to copy file /usr/local/bin/remove-nvidia"; only the
  offline install's `shellprocess-before` runs it), failing if it's still there.
- Removes `packagechooser@desktop`, and fails if it's still there.
- GRUB only, with no bootloader page (AgrOS's hidden boot menu, its theme and the snapshots in it are GRUB's): removes
  `packagechooser@bootloader`, whose choice (Limine by default) the rest of the installer reads. So the `bootloader`
  step is set to GRUB (`efiBootLoader: "grub"`, its `efiBootLoaderVar` removed: with it and no page, no bootloader was
  installed), `pacstrap` and `grubcfg` (their `main.py`) take GRUB when nothing was chosen, and the partition page
  starts on GRUB's settings (`partition.conf`: the boot partition at `/boot/efi`, 512 MB, as CachyOS's GRUB override
  has it), with `allowZfsEncryption: false` there too. Fails if any of these didn't apply.

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

- **AgrOS's packages.** The live system gets `agros-keyring`, `agros-scripts`, `agros-hyprland-settings`,
  `agros-welcome` and `agros-thunar-usage`, plus the AUR packages AgrOS builds into the repo (`quickshell-git`,
  `caelestia-shell`, ...) and the installer, `agros/cachyos-calamares-next` (below). The installed system gets
  `agros-desktop` and everything it pulls in.
- **The installer.** The CI rebuilds CachyOS's `cachyos-calamares` PKGBUILD against today's libraries. CachyOS's own
  build was made for Boost 1.91 and didn't start once Arch moved to 1.92. The rebuild's `pkgrel` is CachyOS's plus `.5`;
  the ISO's package list names it `agros/cachyos-calamares-next` (pacman takes a package from the first repo that has
  it, `[cachyos]`, not the newest), and it carries small fixes for AgrOS's dark theme: the partition names in the
  theme's text colours, the package list's highlight cleared on a click on no row, and the language list's English names
  readable on the highlighted row; and GRUB only: where its compiled modules read the bootloader page's choice (the ZFS
  pool's GRUB compatibility, the partition page's GRUB settings, its BIOS hint, the boot partition on erase-disk), GRUB,
  as `agros-calamares-config` does for the Python ones. The live system has the rebuild that was current when the ISO
  was built; agros's CI starts a new ISO after it publishes packages.

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

The repo is released under the GPL-3.0 (`LICENSE`). The scripts from CachyOS keep their GPL-2.0 headers; see the
[README's license](../README.md#license).
