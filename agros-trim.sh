#!/bin/bash
#
# What AgrOS leaves out of the live ISO, made on the build's own copy of the profile (util-iso.sh, right after it copies
# the package list): CachyOS's files stay as they wrote them, so their changes keep merging by themselves (the CachyOS
# sync, .github/cachyos-sync.sh). Installed systems aren't touched: the installer downloads their packages
# (netinstall.yaml), the LTS kernel too.
#
#   ./agros-trim.sh <the build's copy of archiso/>
#
# - occt: a CPU/GPU stress test
# - the LTS kernel (linux-cachyos-lts and its modules): every boot entry that booted it (BIOS's default, the fallback,
#   network boot) boots the main kernel instead, and the entries that would then be the same twice go: GRUB's "LTS
#   Kernel" (id cachyos-lts) and syslinux's "current kernel" (cos64cur). When CachyOS has reworked its menus so this
#   can't be done cleanly (a file or entry not where it was), the LTS kernel stays, said, and the build goes on: a
#   bigger ISO, never a boot entry without its kernel
set -euo pipefail
p=${1:?usage: agros-trim.sh <the copy of archiso/ the build uses>}
list=$p/packages.x86_64
[[ -f $list ]] || { echo "agros-trim.sh: no $list" >&2; exit 1; }

sed -i '/^occt$/d' "$list"
echo "  -> Left out of the live ISO: occt"

boot=(grub/grub.cfg grub/loopback.cfg syslinux/archiso_sys-linux.cfg syslinux/archiso_pxe-linux.cfg)
keep_lts() { echo "  -> The LTS kernel kept in the live ISO: $1 (agros-trim.sh)"; exit 0; }
for f in "${boot[@]}"; do [[ -f $p/$f ]] || keep_lts "$f is gone"; done
for f in grub/grub.cfg grub/loopback.cfg; do
    grep -q "^menuentry .*--id 'cachyos-lts' {\$" "$p/$f" || keep_lts "no LTS entry in $f"
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# (each file made in $tmp first, all checked, then put in place: never half done)
for f in "${boot[@]}"; do
    # GRUB's LTS entry, its menuentry line through its closing brace; syslinux's current-kernel entry, its LABEL
    # through the blank line after it; then the LTS kernel's files named as the main kernel's
    awk '/^menuentry .*--id .cachyos-lts. \{$/ { skip = 1 }
        skip && /^\}$/ { skip = 0; next }
        /^# AgrOS: CachyOS.s current kernel too/ { next }
        /^LABEL cos64cur$/ { lskip = 1 }
        lskip && /^$/ { lskip = 0; next }
        !skip && !lskip' "$p/$f" | sed 's/linux-cachyos-lts/linux-cachyos/g' >"$tmp/${f##*/}"
done
if left=$(grep -l 'cachyos-lts' "$tmp"/* | paste -sd' ') && [[ -n $left ]]; then
    keep_lts "still named in $left after the changes"
fi
grep -q 'vmlinuz-linux-cachyos ' "$tmp/grub.cfg" || keep_lts "no main-kernel entry left in grub.cfg"
# (every kernel the menus boot after the changes is one the ISO still has: an LTS file under a name this doesn't know,
# renamed to a kernel that doesn't exist, keeps the LTS kernel instead)
for k in $(grep -oh 'vmlinuz-[A-Za-z0-9._-]*\|initramfs-[A-Za-z0-9._-]*\.img' "$tmp"/* | sed 's/^vmlinuz-//; s/^initramfs-//; s/\.img$//' | sort -u); do
    [[ $k == linux-cachyos-lts* ]] || grep -qx "$k" "$list" || keep_lts "a boot entry would boot $k, which isn't in the ISO"
done
for f in "${boot[@]}"; do cat "$tmp/${f##*/}" >"$p/$f"; done
sed -i '/^linux-cachyos-lts\(-.*\)\{0,1\}$/d' "$list"
echo "  -> Left out of the live ISO: the LTS kernel (its boot entries boot the main kernel)"
