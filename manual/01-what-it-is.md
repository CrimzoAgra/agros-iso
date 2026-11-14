# What the ISO is

The AgrOS ISO is a bootable USB image that installs [AgrOS](https://github.com/CrimzoAgra/agros). It's a fork of
CachyOS's live ISO, set up the way CachyOS sets up its own editions:

- AgrOS's repo, `[agros]`, is in the live system's and the installed system's `pacman.conf`.
- The installer's package list has one AgrOS group, `agros-keyring` and `agros-desktop`, next to CachyOS's base.
- The live session is AgrOS's desktop (Hyprland with the Caelestia shell), not CachyOS's KDE.
- The installer, boot menus and console welcome say AgrOS, and the installer has AgrOS's look.

The installer downloads every package during the install, so the ISO stays small and the installed system starts out
up to date. It needs an internet connection for that.

A new ISO is published after each change to what goes into it, or to AgrOS's packages: [download the
latest](https://sourceforge.net/projects/agros-iso/files/latest/download) (see [Download](../README.md#download)). To
build one yourself on an Arch or CachyOS machine, read on.

Next: [What you need](02-requirements.md)
