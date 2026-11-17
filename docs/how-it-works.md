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
| `util.sh` | Helpers: the timer, the build's requirements (`check_requirements`), no `$` in AgrOS's commands for Calamares (`check_calamares_commands`), every name in the installer's package list in the repos (`check_netinstall`), checksums (`create_chksums`), signing (`sign_with_key`) and checking a signature is AgrOS's (`verify_agros_sig`), the upstream gate (`gate_list`, `gate_plan`, `gate_waits`, `check_gate`: the ISO's Hyprland and its libraries only at versions AgrOS's CI approved; `gate_fetch` and `gate_verify`: their copy kept on the ISO for the installer), a key file's fingerprint (`key_fpr`), the output folder (`iso_out_dir`, `out/desktop`) and the newest ISO in it (`newest_iso`), the user who ran `sudo` (`invoking_user`, `as_invoking_user`); also used by `upload-iso.sh`, `testiso.sh` and the ISO workflow |
| `util-iso.sh` | The build itself: `prepare_profile` and `run_build`, the console welcome, the ISO's file name |
| `agros-trim.sh` | What the live ISO leaves out, made on the build's copy of the profile (`prepare_profile` runs it), never on CachyOS's own files, so their changes keep merging by themselves. Packages the live session and installer don't use (`leave_out`: `occt`, Plasma's screen reader, rescue-disk network and backup tools, extra editors, a second Chinese font, `cloud-init`, CachyOS's text installer, the UEFI Shell, disk admin tools, a test web server, an X11 mouse tool, and `gcc`, which CachyOS's installer no longer uses to find the CPU's level). Files inside packages never unpacked (`NoExtract` under `[options]` in the build's `pacman.conf`; the live system's own `/etc/pacman.conf` has none): the font styles nothing names (of JetBrains Mono, Cascadia and Material Symbols), Hyprland's own wallpapers, the pointer's 11 Bibata styles but the desktop's (`Bibata-Modern-Ice`), the programs' translations (the live system is `LANG=C.UTF-8`; the installer's and those it may show are kept), man and info pages, docs, NVIDIA's OptiX and DLSS libraries (games' and 3D renderers' only), CUDA's compilers and debugger and Vulkan SC (only libcuda loads them), C headers and static libraries (no compiler on it), Qt 5 and KDE Frameworks 5 (only qtengine's Qt 5 plugin needs them; the installer and the shell are Qt 6), Noto CJK's serif and extra sans weights, Marvell's network-switch firmware and nouveau's older (535) GSP firmware. Installed systems leave out only the font styles, Bibata styles, Hyprland's wallpapers and docs (fish's and HPLIP's kept), from the first package: the installed system's `pacman-more.conf` gets them (marked `# agros-iso`), which `agros-system`'s install swaps for its Include of `agros-noextract.conf` in AgrOS's repo (keep the two the same). And the LTS kernel: every boot entry that booted it boots the main kernel; GRUB's "LTS Kernel" and syslinux's duplicate "current kernel" entries go (installed systems keep both kernels: the installer downloads them). A package name CachyOS renamed or dropped, menus that no longer look as it expects (the LTS kernel kept), or NoExtract not added: said in the build's log on a line ending in "(agros-trim.sh)", which agros's weekly size watch also puts in the Friday status, and the build goes on |
| `util-iso-mount.sh` | Unmounts what a stopped build left mounted |
| `util-msg.sh` | Coloured messages (`msg`, `warning`, `error`, `die`; on GitHub, warnings and errors are also annotations on the run) and `import`; also used by `upload-iso.sh`, `testiso.sh`, `agros-trim.sh` and the ISO workflow's upstream gate step and publish job |
| `upload-iso.sh` | Uploads a built ISO, with its `.sha256`, `.sig` and `.pkgs.txt`, to SourceForge (`buildiso.sh -u`, or by hand): see [Publishing the ISO](../manual/03-building.md#publishing-the-iso) |
| `agros.asc` | AgrOS's public signing key (packages and ISOs), for checking a downloaded ISO's `.sig` |
| `.github/workflows/iso.yml` | GitHub publishes a new ISO after each change: a push of `main` (not one of only docs), or AgrOS's packages changed (agros's CI starts it after publishing them); three jobs: `sourceforge` checks SourceForge's key; `iso` builds with no secrets (it runs packages' install scripts as root; `AGROS_SIGN_LATER` leaves signing to the next job); `publish` signs and uploads (to SourceForge, and to Cloudflare R2 as `agros-latest.iso`, the README's download), running only official Arch packages' scripts (the key kept from the build's, not the ISO checked: it's signed as built), and, on a re-run, only if no newer run has published since. See [Published by itself](../manual/03-building.md#published-by-itself) |
| `testiso.sh` | Boots the newest ISO in a VMware Workstation VM (made the first time; `--fresh` for a new empty disk) |
| `tests/` | `tests/run.sh` (or `tests/run.sh <name>...`): the scripts on throwaway copies, nothing built (`agros-trim.sh` on copies of the profile's menus, package list and `pacman.conf` files in `tests/fixtures/profile`, and on the repo's own `archiso/`; `newest_iso`; the CachyOS sync's `prepare` and `merge` on throwaway repos, and the choice its workflow's last step makes; `upload-iso.sh` under sudo, a dry run, skipped without `sudo -n`). Run on Linux, after each push of `main` by `.github/workflows/tests.yml`, and by the CachyOS sync on its merge before `main` moves to it (its pushes, with GitHub's token, start no workflow); the ISO workflow doesn't wait for it. A failing `agros-trim` on the repo's own profile in a CachyOS merge: the trim no longer fits their menus (the ISO would keep the LTS kernel), and the merge waits as a pull request |
| `archiso/profiledef.sh` | The profile: ISO name `agros`, label `AGROS_YYYYMM`, boot modes `bios.syslinux` and `uefi.grub`, squashfs with zstd (level 19), file permissions |
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
| `etc/pacman.conf`, `etc/pacman-more.conf` | The live system's and the installed system's `pacman.conf`, both with `[agros]`. Neither includes AgrOS's upstream gate: `agros-system` adds that line to the installed one as it installs its file (`/etc/pacman.d/agros-gate.conf`), as this one is in place before anything is installed and pacman can't read a config including a missing file |
| `etc/greetd/config.toml` | Logs `liveuser` straight into Hyprland (`uwsm start -e -D Hyprland hyprland.desktop`); logged out, `agreety` starts it again |
| `etc/xdg/autostart/agros-install.desktop` | Opens the installer when the session starts |
| `etc/xdg/autostart/live-session-menu.desktop` | Runs `live-session-menu` when the session starts |
| `home/liveuser/.config/quickshell/sidedock/pins.json` | An empty list: no pinned apps in the dock |
| `usr/share/applications/agros-install.desktop` | **Install AgrOS** in the Super menu; its `StartupWMClass` gives the installer's window AgrOS's icon in the dock |
| `usr/local/bin/calamares-online.sh` | Starts the installer (below) |
| `usr/local/bin/agros-calamares-config` | AgrOS's installer settings (below) |
| `usr/local/bin/agros-gate-install` | The installer's upstream gate step (below) |
| `usr/local/bin/live-session-menu` | Sets Caelestia's `launcher.hiddenApps` in the live user's `shell.json` to hide every app but `agros-install`, `foot`, `thunar`, `librewolf` and `gparted`, and `launcher.favouriteApps` to none, and keeps only the screen-off idle timeouts in `general.idle.timeouts` (the installed system's suspend after 30 minutes, 15 on battery, put the computer to sleep halfway through a long install no one touched; set to that list, never removed, or Caelestia takes its own: a lock and a suspend), through agros-scripts' `json-edit` (the file's other writers' lock; one Caelestia is mid-rewrite is tried again, never reset) |
| `etc/systemd/sleep.conf.d/do-not-suspend.conf` | The live system never sleeps, whoever asks (`AllowSuspend=no` and the hibernate kinds): the installer runs on its own D-Bus, so its inhibitor reaches no one, and the live user's polkit rule lets a suspend past one anyway. `logind.conf.d/do-not-suspend.conf` ignores the sleep keys and the lid. The install copies neither to the new system |
| `usr/local/bin/pkexec-wrapper` | Runs the installer as root under Hyprland (below) |
| `etc/pacman.d/hooks/agros-live-rate-mirrors-off.hook` | Turns `cachyos-rate-mirrors.timer` off on the live system once its package has enabled it (only for the build: removed afterwards, as CachyOS's build-time hooks are) |
| `etc/pacman.d/hooks/zz-agros-live-branding.hook`, `agros-live-branding` | Puts AgrOS's name back in `/etc/os-release` and `/etc/lsb-release` after CachyOS's hooks have written CachyOS's there, as `agros-system`'s `agros-branding` does on the installed system (only for the build, removed afterwards) |
| `usr/share/agros/netinstall.yaml` | The installer's package list |
| `usr/share/agros/installer-splash/` | The splash shown while the installer gets ready (below) |
| `usr/share/calamares/branding/agros/` | The installer's branding (below) |

## A build, step by step

`sudo ./buildiso.sh -p desktop -w` runs these, in order:

1. **Options.** `-c`, `-r`, `-w`, `-f`, `-a`, `-u`, `-p` and `-h`, as in [Building the ISO](../manual/03-building.md);
   any other, or an argument, stops it, as does a `$` in AgrOS's commands for Calamares (`check_calamares_commands`:
   its installer would never open). The work folder is `build/` (with `-r`, a `mktemp` folder in `/tmp`, RAM, if it
   has 14 GB free: the live system unpacked, about 7.6 GB, and the ISO's files with its squashfs, about 3.3 GB); the
   output is `out/desktop/` (`iso_out_dir`). `check_requirements` installs what the build needs on the host and is
   missing (`archiso`, `git`, `grub`: the one list of them; `squashfs-tools` comes with `archiso`, and
   `mkinitcpio-archiso` goes into the ISO from its package list) with `sudo pacman -S`, or stops with the command to
   run. It also stops when `pacman -Qkk archiso` finds `/usr/bin/mkarchiso` edited (older checkouts
   edited it in place), with the command that restores it. Then `check_gate`: the Hyprland and libraries the ISO
   would get must be on AgrOS's approved list (`agros-approved` beside the `[agros]` repo), else it stops (exit code
   75, which the ISO workflow reads as a wait, as its own gate step's) and the published ISO stays the download
   (`AGROS_UNGATED=1` builds anyway, with a warning, even with no list: a test build, `-ungated` in the ISO's name,
   never signed with AgrOS's key, which `upload-iso.sh` refuses, and `buildiso.sh -u` with it stops at once; its copy
   marked `ungated`, which the installer never takes as approved). The list is fetched once a build, with a time limit,
   from `[agros]`'s servers in turn (GitHub Pages, then its R2 mirror), and taken only with a good signature by AgrOS's
   key beside it (`agros-approved.sig`, agros's CI signs it; `verify_agros_sig`, against `agros.asc` alone): none, or a
   bad one, from every server, stops the build as a list it can't fetch does
   (a file the later steps read, in a folder of its own; with `AGROS_UNGATED`, none found is remembered too). Those packages are also downloaded into the live system's files (`/opt/agros/gate`, `gate_fetch`, as
   the profile is set up: step 3; those packages alone, not what they need) for the installer, and checked once the
   ISO is made, before it takes its name (`gate_verify`, on mkarchiso's own tree, what went into the ISO): only gated
   packages, every gated one the ISO has, at its own versions (a mirror updated mid-build, or the installer would put
   in another Hyprland than the live system's) and approved; else the ISO is deleted and the build stops.
   Then `check_netinstall`: every package name in the installer's list (`netinstall.yaml`) one the build's repos have
   (by name, group or what a package provides), else the build stops, naming them: one CachyOS renamed or dropped
   failed every install at its pacstrap step, after the disk was partitioned.
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
   (`ZPOOL_VDEV_NAME_PATH=1`); `etc/edition-tag` (`desktop`); and the installer's Hyprland copy (`gate_fetch`, step 1). Any profile but `desktop` stops the build at once
   (`buildiso.sh`, right after its options), before anything is deleted or downloaded. With
   `-f`, it lowers the copy's squashfs zstd level (`profiledef.sh`) from 19 to 6, and stops if that line didn't change.
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
   day don't share a name; `-ungated` at its end for a test build, step 1), once `gate_verify` passed, and the live
   system's package list is copied next to it as `.pkgs.txt`.
7. **Checksums and signature** for that ISO only: `.sha1` and `.sha256`, then a detached `.sig`. `sign_with_key` signs
   with AgrOS's key, the one in `agros.asc` (`23B6096B42D05E1E`, the one `agros-keyring` holds; read from the file, as
   the ISO workflow does for its pacman keyring), always: a `GPGKEY` in a `makepkg.conf` isn't read, since the upload
   refuses a signature by any other key. It signs as the user who ran `sudo` (`as_invoking_user`), with their keyring. With
   `AGROS_SIGN_LATER` set (the ISO workflow's build) it leaves the ISO unsigned, said, for a later step to sign.
   Without the key, or when gpg fails (no passphrase, pinentry or primary key), it warns and skips the signature; the
   cleanup and upload still run. Signing each build's ISO alone, not every ISO in the folder again, is an AgrOS
   change.
8. **Cleanup.** With `-w` it deletes the work folder. The exit trap, there to report a build that stops halfway, is
   cleared at the end, so a good build no longer ends with "An unknown error has occurred". A build that stops says
   why once (its own error, or "An unknown error has occurred" for a failed command), unmounts once, and with `-r`
   says where the work folder is, still in RAM (one with nothing built in yet is removed instead). The traps are set
   before anything is made. The upstream gate's folder (`gate_dir`: the approved list and the package lists its check
   read) is removed at the end or on a stop, and the build's exit code is kept through the trap (75: a wait for the
   upstream gate, not a failure).
9. **Upload**, with `-u` only: `upload-iso.sh` on the ISO just built. Run as root, it starts itself again as the
   user who ran `sudo` (`as_invoking_user`: `sudo -u "$SUDO_USER" -H`), so ssh and `~/.config/agros-iso/upload.conf`
   are that user's. It refuses (exit code 65) a test build (`-ungated` in its name), an ISO that doesn't match its
   `.sha256`, or whose `.sig` isn't a good
   signature by AgrOS's key: `verify_agros_sig` checks it with `gpgv` against a keyring of `agros.asc` alone (not the
   user's keyring, so no other key passes) and matches the `VALIDSIG` fingerprint with `agros.asc`'s. An ISO with no
   `.sig` goes up with a warning (`buildiso.sh -u`); with `--signed`, as the ISO workflow uses it, it's refused too.
   Then it copies the files to SourceForge's file release system with rsync (or scp), and with `SF_API_KEY` set makes
   the ISO the default download through SourceForge's API. The ISO workflow tries the upload 3 times, but not after a
   refusal.

## What AgrOS changes from CachyOS's ISO

- `archiso/pacman.conf`, `archiso/airootfs/etc/pacman.conf` and `pacman-more.conf` (the installed system's) get the
  `[agros]` repo, its database's signature required too (`SigLevel = Required DatabaseRequired`; `agros-system`'s
  install adds the line on machines installed before); `packages_desktop.x86_64` gets `agros-keyring`, whose key the installer trusts
  (`calamares-online.sh`) and copies to the installed system.
- `archiso/airootfs/usr/share/agros/netinstall.yaml`: CachyOS's package list (the installer package's
  `/etc/calamares/modules/netinstall.yaml`) plus the AgrOS group (hidden, selected and critical: `agros-keyring` and
  `agros-desktop`). It's in `/usr/share/agros` because the installer package owns CachyOS's. What's different, and why:
  - No other desktops or window managers (KDE, GNOME, Cosmic, Niri, Cinnamon, Budgie, MATE, Xfce, LXQt, LXDE,
    CachyOS's Hyprland, MangoWM, Sway, Wayfire, i3, Qtile, bspwm, Openbox): `agros-desktop` is the desktop.
  - No **CachyOS Handhelds** group: its `cachyos-handheld` brings Plasma's login manager and Steam's gamescope session,
    a second login screen and desktop next to AgrOS's. No hidden handheld kernels group either, and no `platform:`
    keys: CachyOS's newer installer installs every group whatever its platform, so the handheld kernel went on every
    PC.
  - No **Support for HP Printer/Scanner** group (unticked by CachyOS): `agros-desktop` has CUPS and HPLIP already.
  - No **Plymouth** group (the boot splash): `agros-desktop`'s `agros-boot` needs the same three packages.
  - No **Firefox and language package** (`agros-desktop` has LibreWolf), Alacritty (AgrOS's terminal is foot),
    `cachyos-hello` (AgrOS has `agros-welcome`), `cachyos-fish-config` and `cachyos-micro-settings`
    (`agros-hyprland-settings` has AgrOS's own fish and micro settings in `/etc/skel`, and replaces them).
  - `pipewire-jack` added: with nothing named for JACK, `pacman --noconfirm` picked `jack2`, which conflicts.
  - Nothing AgrOS doesn't use (about 750 MiB on every install): `cachyos-kernel-manager` (its sched-ext schedulers
    with it) and `cachyos-wallpapers` (AgrOS's are Caelestia's), the **CachyOS shell configuration** group (zsh,
    oh-my-zsh, Powerlevel10k: AgrOS's shell is fish) and its `ttf-meslo-nerd` font, `vlc-plugins-all` (no VLC: the
    player is mpv), `pavucontrol` (`agros-desktop` has `pwvucontrol`, Caelestia's), `shelly` (packages are installed
    with paru and Flatpak), and `meld`, `glances`, `hwinfo`, `duf`, `fsarchiver` and `pv`. None of them is used by
    AgrOS's configs and scripts or by Caelestia's dots. Kept when CachyOS's list is merged in by hand.
- `archiso/airootfs/usr/local/bin/agros-calamares-config`, run when the installer starts, points the installer at that
  list, removes the desktop page, and makes CachyOS's greetd step (`shellprocess@greetd`) start AgrOS's login
  screen, adding the step where CachyOS's settings don't have it (its newer branches).
- The live system is named AgrOS: `airootfs/etc/os-release` (`NAME`, `PRETTY_NAME`, `LOGO=agros-logo`), kept so by
  `zz-agros-live-branding.hook` once CachyOS's `cachyos-hooks` has renamed it CachyOS, and `airootfs/etc/hostname`
  (`agros`).
- The network-boot (PXE) menu entries drop `cms_verify=y` (`archiso/syslinux/archiso_pxe-linux.cfg`, the reason in a
  comment there).
- The live system's installer is AgrOS's rebuild from `[agros]` (`agros/calamares` in
  `packages_desktop.x86_64`): CachyOS's own can lag behind an Arch update and not start.
- The live session is AgrOS's own desktop, not CachyOS's KDE: `packages_desktop.x86_64` has Hyprland, Caelestia and
  AgrOS's settings instead of Plasma (the big apps of `agros-desktop` only go on the installed system), and greetd logs
  the live user straight into it (`airootfs/etc/greetd/config.toml`, enabled by `util-iso.sh`). CachyOS's Plasma
  login and KDE settings in `etc/skel` are gone. The installer opens when the session starts, and is "Install AgrOS"
  in the app menu. The menu and dock are cut down to what installing needs (`live-session-menu`, the empty
  `pins.json`). `gvfs` puts drives and USB sticks in Thunar's side panel, and `ntfsprogs` lets the installer shrink
  Windows' partition (`tests/installer-tools.sh` checks the tools its partitioning calls are on the ISO).
- The installer is AgrOS's: its branding (`airootfs/usr/share/calamares/branding/agros`: the name, the logo and name as
  in AgrOS's README, its colours), AgrOS in its steps, the suggested computer name (`agros-...`) and the firmware's
  boot entry (`AgrOS`).
- The boot menus say AgrOS (GRUB and the BIOS menu; the kernel's own files keep their names). CachyOS's unused
  systemd-boot entries (`efiboot/`), its `usr/local/bin` scripts for its offline install and its desktops
  (`remove-nvidia`, `removeun`, `removeun-online`, `choose-mirror`, `prepare-live-desktop.sh` and `dmcheck`; the last
  two the installer would copy to the new system and run there: out of its steps, below) and its `linux.preset` (for Arch's `linux`, not on the ISO:
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
  require it); `bootstrap_packages.x86_64` (only for archiso's bootstrap build mode, not `iso`); the `linux-atm`
  package (ADSL modems' ATM tools); and archiso's SSH server, started at boot and taking root's password login
  (`sshd.service` enabled, `etc/ssh/sshd_config.d/10-archiso.conf`).
- The ISO is named `agros`, and its console welcome (`util-iso.sh`'s motd) is AgrOS's.
- The build: `-f`, `-a`, `-u` (upload to SourceForge), the low priority and half-CPU default, the per-ISO checksums and
  signature with AgrOS's key, only git's tracked files of the profile, and no "unknown error" after a good build.

## The installer

### Starting it

`calamares-online.sh` (CachyOS's, with AgrOS's lines):

1. Already running (a lock in `$XDG_RUNTIME_DIR`, held until the installer closes), it doesn't start a second one: its
   window, open, is brought forward (the desktop's `dots.focus_window`: focused and raised over other windows); its
   process there with no window yet (opening or closing), its window or its end waited for, up to 30 s (then brought
   forward, or a new one started); still getting ready, its splash is up already.
2. Waits for Caelestia's bar (its IPC answering, up to 20 s), then opens a splash (`/usr/share/agros/installer-splash`,
   Quickshell: the logo, a spinner and a line from a status file it writes: "Getting the installer ready", or, offline,
   to connect), closed once the installer's window is up or when it stops: its window takes a minute or two. It's drawn
   on the CPU (`LIBGL_ALWAYS_SOFTWARE=1`): started from the session's autostart, a systemd unit, it doesn't get what the
   desktop sets in Hyprland's own environment, and on VMware's GPU Hyprland refused its window, never seen. Waits for
   the internet (`nmcli networking connectivity check`: `full`). Not connected, as on Wi-Fi at the first login, it
   also says "Connect to the internet to install" once in a notification and checks every 2 seconds, for up to 5
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
as the partition names, from the palette and not the stylesheet; qtengine when it's unset, as it is at login (the
autostart's systemd unit doesn't get Caelestia's Hyprland environment).

### AgrOS's settings

`agros-calamares-config` edits CachyOS's settings in `/etc/calamares` after `calamares-online.sh` has put them there:

- `netinstall.conf`: the package list, the ISO's own copy alone (`file:///usr/share/agros/netinstall.yaml`), never
  one fetched from GitHub: a bad push to `main` would have broken every install started after it, on ISOs already
  out, and Calamares can run commands from a group file as root. A change to `netinstall.yaml` builds a new ISO
  anyway (`iso.yml`, after the push), which is how it reaches new installs.
- `shellprocess_agrosgate.conf` (just before the next one, on the live system: `dontChroot`): `agros-gate-install`.
  The install downloaded the newest Hyprland and libraries; one not on AgrOS's approved list (a new Hyprland not
  checked yet), or no list reachable, and the ISO's own copy (`/opt/agros/gate`) is installed over them, all together
  (`pacman --sysroot ... -U`, from a copy inside the new system). One whose libraries no longer fit it: the newest kept;
  the installed system's updates hold it until approved. Only the gated packages the new system has are put in (each
  keeping why it was installed), and a rebuild of the same version (CachyOS's for newer CPUs, `-1.1`) counts as the
  same. What it did is in the new system's `/var/log/agros-gate-install.log`. AgrOS's per-user package hooks
  (hyprbars built for each account) don't run in it (`AGROS_NO_USER_HOOKS`): the first login does that. The new
  system's root is Calamares's `${ROOT}`; the approved list comes from the live system's own `pacman.conf`'s
  `[agros]` servers (the new system's includes the gate's file, which the live system lacks), fetched with a few
  tries and checked as the build's is (step 1; here against `agros-keyring`'s key file): with no good signature, it's
  as unreachable, said. The copy goes in
  only when it's approved itself: on the list, or, with the list unreachable, from a build that checked it (a test
  build's copy, marked `ungated`, never). A gated package installed that the copy hasn't (an ISO built before it was
  gated), not approved, is said, and held by the new system's updates. pacman there is never cut off (interrupted, it
  stops between packages: a set half the ISO's): the step has an hour, as CachyOS's own have, and what's installed
  after it (all, none, or which) is said as it is. The command starts with `-`: its failure, or its timeout, never
  fails the install
- `shellprocess_greetd.conf` (one of the install's last steps, in the new system: after the bootloader and the
  services, before the installation snapshot and the cleanup): removes the six `.pacnew` files of the
  live system's pacman.conf, resolv.conf and mirror lists; clears the downloaded packages from pacman's cache (`paccache -rk0`, about 4 GB the install left there; kept otherwise until three newer versions of each came); deletes the snapshots the install's own package runs made
  (the boot menu's list starts with the installation's alone); runs agros-boot's `boot-menu` and `splash-theme` now
  that GRUB is set up (agros-boot's own install runs before `/boot/grub` exists, and the `grubcfg` and `plymouthcfg`
  steps set CachyOS's after it; on an AMD GPU `splash-theme` keeps the plain `cachyos` theme CachyOS's `plymouthcfg`
  picks there, as its animated one breaks on some AMD GPUs); and last, copies `caelestia-greeter`'s greetd
  config into place and enables greetd (CachyOS's installer enables greetd only for its `noctalia-greeter`, so without
  this AgrOS would boot to a text login). Added where CachyOS's settings don't have it (the `cachyos` branch), before
  the btrfs snapshot whichever module takes it (a `shellprocess` script, or `gucc`, CachyOS's installer's own code, on
  their newer branches), else before the cleanup; one after the snapshot (it would delete it) fails. It has an hour,
  as CachyOS's own steps have (both kernels' initramfs rebuilt, other systems looked for on every disk): cut off, it
  would fail the whole install at its end.
- `shellprocess_agrossnapshot.conf` (right after CachyOS's btrfs snapshot step, in the new system): names the
  installation's snapshot "Fresh AgrOS Installation" (`snapper modify`: `gucc` names it in C++, so not in a script of
  theirs) and remakes GRUB's menu, so the snapshot is in it from the first boot (grub-btrfsd only adds snapshots taken
  after it starts). No snapshot step: said, and not added. No snapshot described "Fresh ... Installation" (CachyOS
  named it otherwise): said, none renamed. Each of its failures said, never the install's.
  Its command, as the greetd step's, has no dollar sign at all: Calamares reads `$name`/`${name}` in a shellprocess command as its own
  variable (one it doesn't know stops the whole install), turns `$$` into `\$`, and tracks quotes without knowing
  shell comments. `agros-calamares-config` refuses to start the installer with one, and `buildiso.sh` refuses to build
  an ISO with one (`check_calamares_commands` in `util.sh`).
- `branding: agros` in `settings.conf`; AgrOS in place of CachyOS in the names of the `shellprocess-before` steps;
  `agros-${cpu}` as the suggested computer name and no "Log in automatically" box (`users.conf`, `displayAutologin`
  and `doAutologin` false: greetd's login screen isn't one the installer's display manager step sets up, so it would
  do nothing); `efiBootloaderId: "AgrOS"` (`bootloader.conf`), the
  firmware's boot entry and GRUB's folder `EFI/AgrOS`.
- The room AgrOS needs, 20 GB (`welcome_online.conf`'s `requiredStorage`, CachyOS's 8): the welcome page checks it,
  and the partition page leaves at least that plus 2.1 GB for the new system beside Windows (plus 0.5 GB in place of
  a partition). A new install is about 14 GB of packages, with about 4 GB more downloaded while it installs (cleared at
  its end); at CachyOS's 10 GB beside Windows it would run out of room halfway, after Windows' partition was shrunk. Not
  set (CachyOS moved the setting): said, and the installer starts as before.
- CachyOS's `remove-nvidia` and `dmcheck`, scripts of its ISO that AgrOS's doesn't have, out of what the install copies
  to the new system (`pacstrap.conf`'s `postInstallFiles`: each install logged "Failed to copy file") and runs there
  (`shellprocess.conf`: CachyOS's `cachyos` branch runs `/usr/local/bin/dmcheck`, which picks the login screen, as the
  greetd step does; missing, it failed the install at its end, after the disk was wiped), with the keys of a command
  under it; fails if either is still there. Any other command of the install's steps from `/usr/local/bin` that the
  ISO doesn't have stops it the same way, before anything is changed on the disks (not one allowed to fail, its `-`).
- Removes `packagechooser@desktop`, and fails if it's still there.
- GRUB only, with no bootloader page (AgrOS's hidden boot menu, its theme and the snapshots in it are GRUB's): removes
  `packagechooser@bootloader`, whose choice (Limine by default) the rest of the installer reads. So the `bootloader`
  step is set to GRUB (`efiBootLoader: "grub"`, its `efiBootLoaderVar` removed: with it and no page, no bootloader was
  installed), `pacstrap` and `grubcfg` (their `main.py`) take GRUB when nothing was chosen, and the partition page
  starts on GRUB's settings (`partition.conf`: the boot partition at `/boot/efi`, 512 MB, as CachyOS's GRUB override
  has it), with `allowZfsEncryption: false` there too. Fails if any of these didn't apply.
- Installing beside Windows: an EFI partition already on the disk is used down to 64 MB (`partition.conf`'s
  `efi.minimumSize`, added; a minimum CachyOS sets is kept), not refused below the 512 MB a new one is made. Windows
  makes its own 100 MB, and **Install alongside** and **Replace a partition** stayed greyed out ("too small"); GRUB needs
  a few MB there, the kernels being on the system's partition. agros's rebuild of the installer checks this minimum on
  the install-type page (CachyOS's checks the 512 MB).
- Beside Windows, the firmware's fallback loader (`EFI/Boot/bootx64.efi`, Windows' copy of its boot manager) is
  kept: CachyOS's `bootloader.conf` has `installEFIFallback: true`, and the `bootloader` step (its `main.py`) copied
  GRUB over it. A machine that starts Windows by that path, or whose boot entries were lost (a firmware update, a
  reset), then came to AgrOS instead, or with Secure Boot on maybe to nothing (GRUB's copy isn't signed). The copy is
  made only when there's no `EFI/Microsoft/Boot/bootmgfw.efi` on the boot partition, so a disk with AgrOS alone still
  gets it. Not patched (CachyOS changed the step): said, and the installer starts as before.

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
GitHub Pages, signed with AgrOS's key. Its second server, `https://pub-f1a3a482900748e8b69cd81361ab96e1.r2.dev/repo/$arch`
(Cloudflare R2, the bucket the ISO is downloaded from; agros's `mirror.yml` copies Pages there after each CI run), is
listed after it in all three `pacman.conf` files, so pacman goes there only when Pages can't be reached:

- **AgrOS's packages.** The live system gets `agros-keyring`, `agros-scripts`, `agros-hyprland-settings`,
  `agros-welcome`, `agros-hyprbars` and `agros-thunar-usage`, plus the AUR packages AgrOS builds into the repo (`quickshell-git`,
  `caelestia-shell`, ...) and the installer, `agros/calamares` (below). The installed system gets
  `agros-desktop` and everything it pulls in.
- **The installer.** The CI rebuilds CachyOS's `cachyos-calamares` PKGBUILD against today's libraries. CachyOS's own
  build was made for Boost 1.91 and didn't start once Arch moved to 1.92. The rebuild's `pkgrel` is CachyOS's plus a dot
  and AgrOS's own number; the ISO's package list names it `agros/calamares`: `[agros]`'s (pacman takes a package from
  the first repo that has it, `[cachyos]`, not the newest), by what it provides, so the ISO has it whatever CachyOS
  names the package (`cachyos-calamares-next` until 2026-11-17, `cachyos-calamares` since); and it carries small fixes for AgrOS's dark theme: the partition names in the
  theme's text colours, the package list's highlight cleared on a click on no row, and the language list's English names
  readable on the highlighted row; and GRUB only: where its compiled modules read the bootloader page's choice (the ZFS
  pool's GRUB compatibility, the partition page's GRUB settings, its BIOS hint, the boot partition on erase-disk), GRUB,
  as `agros-calamares-config` does for the Python ones; and an existing EFI partition checked against the minimum size,
  not the size of a new one (Windows' 100 MB one can be installed beside). The live system has the rebuild that was current when the ISO
  was built; agros's CI starts a new ISO after it publishes packages.

So the repo has to be published before you build: the build's pacman reads it, and so does the installer.

## Following CachyOS

`upstream` is `https://github.com/CachyOS/CachyOS-Live-ISO`. Each day the CachyOS sync workflow
(`.github/workflows/cachyos-sync.yml`, its script `.github/cachyos-sync.sh`) takes in their new commits by itself
when that's safe:

1. Their `master` is pushed as the branch `cachyos`, and merged into `main` on a branch of its own,
   `cachyos-merge`, if it has no conflicts and keeps what AgrOS changed on purpose: none of the packages AgrOS left out
   of their list comes back (in it at the last merge, not in AgrOS's), no KDE package is added (`plasma*`, `kde*`,
   `kf6*`, `breeze*`), AgrOS's own installer (`agros/calamares`) stays, and it changes none of the files that run as
   root or decide what's trusted (the build's scripts, the workflows, keys, `profiledef.sh`, the `pacman.conf` files,
   and in the live system sudo, polkit, systemd units, SSH, the accounts, root's files, `usr/local/bin` and the
   installer's settings: `sensitive` in the script): those are looked at first.
2. That merge's ISO is built (`iso.yml` with `check`: nothing published), and the tests run on it (`tests.yml`, in a
   job of its own with a read-only token: CachyOS's code runs there).
3. It built: `main` moves to the merge (only forward: if `main` moved on meanwhile, step 4 instead; a push refused for
   anything else, a rule or the token, fails the run) and the ISO workflow is started, which publishes it as after any
   push.
4. Anything else (a conflict, a package check, the ISO not building, a test failing, its Hyprland waiting for AgrOS's
   check): a pull request from `cachyos` into `main`, opened or brought up to date, lists their commits, the files they
   change, those that conflict, and why it wasn't merged by itself. GitHub notifies of it. Merged on GitHub when it has no
   conflicts; otherwise by hand:

```bash
git pull upstream master
```

The workflow needs the repo's Settings > Actions > General > "Allow GitHub Actions to create and approve pull
requests".

GitHub turns a public repo's scheduled workflows off after 60 days without a commit, and a quiet CachyOS can go that
long with nothing merged. Once a month `.github/workflows/keepalive.yml` turns every scheduled workflow here (the sync,
itself) on again through GitHub's API (`gh api -X PUT repos/<repo>/actions/workflows/<file>/enable`, with
`actions: write`), as keepalive-workflow v2 does: no dummy commits. That it works can only be seen once 60 days pass
with no commit; until then agros's Friday status, which says a daily run not seen for 3 days, is what says it stopped.

When CachyOS changes its package list, update `netinstall.yaml` the same way. After a new CachyOS installer, check the
Partitions and Packages pages and the language list: the installer's fixes are plain text swaps in the agros repo's CI,
each checked after (one an upstream rewrite no longer fits holds the published installer back, said in agros's `held`
issue), but a swap that still applies can look different on a rewritten page.

## Credits

- [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO): the profile, scripts, installer setup and hardware
  detection this repo is a fork of.
- [archiso](https://gitlab.archlinux.org/archlinux/archiso): Arch's ISO builder.
- [Calamares](https://github.com/calamares/calamares): the installer.

The repo is released under the GPL-3.0 (`LICENSE`). The scripts from CachyOS keep their GPL-2.0 headers; see the
[README's license](../README.md#license).
