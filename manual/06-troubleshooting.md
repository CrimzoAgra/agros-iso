# Troubleshooting

## Building

**"Not signed: the key ... isn't in ...'s keyring".** The ISO and its checksums are fine, there's just no `.sig`. Import
AgrOS's signing key into your own gpg keyring (not root's), or set `GPGKEY` in `~/.makepkg.conf` to a key you have,
and build again.

**Packages from `[agros]` aren't found.** The ISO's packages come from the `[agros]` repo
(`https://crimzoagra.github.io/agros/$arch`). Check that it's published and that you can reach it.

**The build is slow.** By default it gets half of the CPU. Use `-a` for all of it, `-f` for a quick test build with
zstd, or `-r` to build in RAM on a machine with more than 23 GB.

**A build stopped halfway.** The build unmounts what it mounted and leaves the work folder (`build/`) behind. The next
build deletes it first, unless you pass `-c`.

**mkarchiso is verbose even without `-v`.** `-v` switches on mkarchiso's own verbose output by editing
`/usr/bin/mkarchiso`, and that stays. Reinstall `archiso` to undo it.

## Booting

**The stick doesn't boot.** Turn off Secure Boot in the BIOS: CachyOS, and so AgrOS, doesn't boot with it on.

**It hangs or the screen stays black.** Pick **AgrOS LTS Kernel** in the boot menu. If that doesn't help either, pick
**AgrOS Legacy Hardware (GPU nomodeset)** on UEFI or **AgrOS Fallback (nomodeset)** on BIOS.

## Installing

**The installer didn't open.** Open **Install AgrOS** from the Super menu.

**The installer fails or won't start.** Each time it starts, it refreshes the package keys, syncs the clock and
installs the latest installer from `[agros]`, so check the internet connection and start it again. Its log, with the
computer's hardware details at the top, is `/home/liveuser/cachy-install.log`. Attach it when you
[report a problem](https://github.com/CrimzoAgra/agros/issues).

Back to the [manual's contents](../README.md#the-agros-iso-manual)
