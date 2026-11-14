<p align="center">
  <picture>
    <source media="(prefers-reduced-motion: reduce)" srcset="docs/images/agros-banner.svg">
    <img src="docs/images/agros-banner-animated.png" alt="AgrOS" width="420">
  </picture>
</p>

# AgrOS ISO

This repo builds the installer ISO for [AgrOS](https://github.com/CrimzoAgra/agros). It's a fork of
[CachyOS's Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO): the same installer (Calamares), CachyOS's kernels and
its hardware detection, with AgrOS's package repo, branding and live session.

Boot the ISO and you get AgrOS's own desktop with the installer already open. It installs CachyOS's base and AgrOS's
desktop from the `[agros]` repo in one go: pacman installs exactly the final set of packages, and nothing is removed or
built afterwards.

## Download

**[Download the latest AgrOS ISO](https://sourceforge.net/projects/agros-iso/files/latest/download)** (about 3.6 GB,
from SourceForge). Every ISO, with its `.sha256` checksum and `.sig` signature:
[sourceforge.net/projects/agros-iso/files/iso](https://sourceforge.net/projects/agros-iso/files/iso/). A new one is
published by itself after each change to what goes into it here (not a change to the docs alone) or to AgrOS's packages.
To check a download, see [Downloading and checking it](manual/03-building.md#downloading-and-checking-it).

## The AgrOS ISO Manual

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
CachyOS (`buildiso.sh`, `util.sh`, `util-iso.sh`, `util-iso-mount.sh`, `util-msg.sh`) keep their own headers, which say
GPL version 2, with no "or any later version". It builds on
[CachyOS's Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), Arch's
[archiso](https://gitlab.archlinux.org/archlinux/archiso) and [Calamares](https://github.com/calamares/calamares); see
[credits](docs/how-it-works.md#credits).
