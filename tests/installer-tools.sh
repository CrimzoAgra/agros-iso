#!/usr/bin/env bash
# What the installer's partitioning (KPMcore) runs is on the ISO: ntfsresize above all, which shrinks Windows' partition
# for "Install alongside". Arch split ntfs-3g (2026.9.28): its tools went to ntfsprogs, and ntfs-3g alone left the
# installer unable to shrink Windows (CachyOS's own list has only ntfs-3g)
source "$(dirname "$0")/lib.sh"
list=$here/archiso/packages_desktop.x86_64
# (each the tool it gives the installer: an ESP, the root, Windows' partition)
for p in ntfsprogs dosfstools btrfs-progs e2fsprogs; do
    grep -qx "$p" <(tr -d '\r' <"$list") || fail "$p isn't on the ISO ($list): the installer's partitioning needs it"
done
echo "ok installer-tools"
