<p align="center">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="docs/images/agros-banner.svg">
    <img src="docs/images/agros-banner-animated.png" alt="AgrOS" width="420">
  </picture>
</p>

# AgrOS ISO

This repo builds the installer ISO for [AgrOS](https://github.com/CrimzoAgra/agros). It's a fork of
[CachyOS's Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO): the same installer (Calamares), kernels and hardware
detection, with AgrOS's package repo, branding and live session. Boot it and you get AgrOS's desktop with the installer
already open. It installs CachyOS's base and AgrOS's desktop from the `[agros]` repo in one go: pacman installs exactly
the final set of packages, and nothing is removed or built afterwards.

Read more in [What the ISO is](manual/01-what-it-is.md).

## Download

**[Download the latest AgrOS ISO](https://pub-f1a3a482900748e8b69cd81361ab96e1.r2.dev/agros-latest.iso)** (about 1.9 GB),
with its [checksum](https://pub-f1a3a482900748e8b69cd81361ab96e1.r2.dev/agros-latest.iso.sha256) and
[signature](https://pub-f1a3a482900748e8b69cd81361ab96e1.r2.dev/agros-latest.iso.sig). A new one is published by itself
after each change to what goes into it here (not to the docs alone) or to AgrOS's packages. Every ISO, the latest too,
with its `.sha256` and `.sig`, is also on [SourceForge](https://sourceforge.net/projects/agros-iso/files/iso/). To check
a download, see [Downloading and checking it](manual/03-building.md#downloading-and-checking-it).

CachyOS's changes to its ISO are merged in by themselves each day, and only when they're safe; how that and every other
update is kept from breaking anything: [How updates stay safe](https://github.com/CrimzoAgra/agros/blob/main/manual/12-updates.md#how-updates-stay-safe).

## The AgrOS ISO Manual

The manual lives in [`manual/`](manual/). To build the ISO yourself, start with [What you need](manual/02-requirements.md).

- [What the ISO is](manual/01-what-it-is.md)

**Building it**

- [What you need](manual/02-requirements.md)
- [Building the ISO](manual/03-building.md)
- [Testing it in a VM](manual/04-testing.md)

**What's on it**

- [The live session and the installer](manual/05-live-session-and-installer.md)
- [Troubleshooting](manual/06-troubleshooting.md)

**For developers**

- [How the ISO works](docs/how-it-works.md): the profile's layout, the scripts, what AgrOS changes from CachyOS's ISO,
  and how the `[agros]` repo fits in

## License

The AgrOS ISO is released under the [GPL-3.0](LICENSE), as CachyOS's Live ISO is. The build scripts that come from
CachyOS (`buildiso.sh`, `util.sh`, `util-iso.sh`, `util-iso-mount.sh`, `util-msg.sh`) keep their own headers: GPL
version 2, with no "or any later version". It builds on [CachyOS's Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO),
Arch's [archiso](https://gitlab.archlinux.org/archlinux/archiso) and [Calamares](https://github.com/calamares/calamares);
see [credits](docs/how-it-works.md#credits).
