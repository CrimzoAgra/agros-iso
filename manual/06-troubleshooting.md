# Troubleshooting

## Building

**"Not signed: AgrOS's key ... isn't in ...'s keyring".** The ISO and its checksums are fine, there's just no `.sig`.
The build signs only with AgrOS's key, the one in `agros.asc` (a `GPGKEY` in a `makepkg.conf` isn't used: the upload
refuses a signature by any other key). Import AgrOS's secret signing key into your own gpg keyring (not root's) and
build again, or upload it unsigned (without `--signed`).

**"Not signed: gpg couldn't sign with AgrOS's key ... (passphrase or pinentry not reached?)".** The key is in your
keyring, but gpg failed to sign: usually its passphrase couldn't be asked for (the build signs with `--batch`, through
gpg-agent). Unlock the key once in the same terminal, for example `echo test | gpg -u 23B6096B42D05E1E --sign
>/dev/null`, so gpg-agent has the passphrase, and build again. The ISO and its checksums are fine either way.

**Packages from `[agros]` aren't found.** The ISO's packages come from the `[agros]` repo
(`https://crimzoagra.github.io/agros/$arch`). Check that it's published and that you can reach it.

**The build is slow.** By default it gets half of the CPU. Use `-a` for all of it, `-f` for a quick test build (a
lower zstd level), or `-r` to build in RAM when `/tmp` has 14 GB free (about 32 GB of RAM).

**A build stopped halfway.** The build unmounts what it mounted and leaves the work folder (`build/`) behind. The next
build deletes it first, unless you pass `-c` to resume it.

**"/usr/bin/mkarchiso was edited".** Older builds edited `/usr/bin/mkarchiso` in place (`pacman -Qkk archiso` shows it
altered); the build stops until it's restored: `sudo pacman -S archiso`.

**"Left out of the ISO, git doesn't track them".** The build copies only the files git tracks in `archiso/`. A new file
of yours: `git add` it. Older builds also left root-owned generated files in `archiso/` (the build now writes them in its
work folder); they're left out without a warning (.gitignore names them); delete them once, from the repo's folder:

```bash
cd archiso && sudo rm -rf packages.x86_64 airootfs/etc/{motd,environment,version-tag,edition-tag,gdm} \
    airootfs/etc/pacman.d/cachyos-mirrorlist \
    airootfs/etc/systemd/system/{display-manager.service,cachyos-rate-mirrors.timer}
```

## Booting

**The stick doesn't boot.** Turn off Secure Boot in the BIOS: CachyOS, and so AgrOS, doesn't boot with it on.

**It hangs or the screen stays black.** Pick **AgrOS LTS Kernel** in the boot menu. If that doesn't help either, pick
**AgrOS Legacy Hardware (GPU nomodeset)** on UEFI or **AgrOS Fallback (nomodeset)** on BIOS. Those two show the
boot's text (the others hide it), so if it still hangs you see where.

## Installing

**The installer didn't open.** Open **Install AgrOS** from the Super menu.

**The installer fails or won't start.** Each time it starts, it waits for the internet (up to 5 minutes, saying
"Connect to the internet to install"), syncs the clock (waiting up to 30 seconds) and makes a
new package keyring with the latest Arch and CachyOS keys from the internet; if that fails it says "The installer
couldn't be set up" and stops before anything is changed. Check the internet connection and start it again (opened
twice, the second one just stops while the first is still open). Its log, with the computer's hardware details at the
top, is `/home/liveuser/cachy-install.log`. Attach it when you [report a
problem](https://github.com/CrimzoAgra/agros/issues).

Back to the [manual's contents](../README.md#the-agros-iso-manual)
