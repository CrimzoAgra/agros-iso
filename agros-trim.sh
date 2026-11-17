#!/bin/bash
#
# What AgrOS leaves out of the live ISO, made on the build's own copy of the profile (util-iso.sh, right after it copies
# the package list): CachyOS's files stay as they wrote them, so their changes keep merging by themselves (the CachyOS
# sync, .github/cachyos-sync.sh). Installed systems aren't touched: the installer downloads their packages
# (netinstall.yaml), the LTS kernel too.
#
#   ./agros-trim.sh <the build's copy of archiso/>
#
# - packages the live session and the installer don't use (CachyOS's ISO has them for its Plasma desktop or as a
#   rescue disk): leave_out below. One no longer in the list (renamed or dropped by CachyOS) is said in the build's log,
#   nothing else: one something else needs comes back as its dependency, so none of this can break the ISO
# - the LTS kernel (linux-cachyos-lts and its modules): every boot entry that booted it (BIOS's default, the fallback,
#   network boot) boots the main kernel instead, and the entries that would then be the same twice go: GRUB's "LTS
#   Kernel" (id cachyos-lts) and syslinux's "current kernel" (cos64cur). When CachyOS has reworked its menus so this
#   can't be done cleanly (a file or entry not where it was), the LTS kernel stays, said, and the build goes on: a
#   bigger ISO, never a boot entry without its kernel
# Each fallback (a name no longer in the list, NoExtract not added, the LTS kernel kept) is a line ending in
# "(agros-trim.sh)": agros's weekly size watch (ci/sizes.sh there) runs this too and puts those lines in the Friday
# status, so keep that ending on them
set -euo pipefail
src_dir=$(dirname "$(readlink -f "$0")")
# (the build's messages: msg2, die)
source "$src_dir/util-msg.sh"
p=${1:?usage: agros-trim.sh <the copy of archiso/ the build uses>}
list=$p/packages.x86_64
[[ -f $list ]] || die "agros-trim.sh: no %s" "$list"

leave_out=(
    occt                                    # a CPU/GPU stress test
    orca espeak-ng brltty                   # Plasma's screen reader, speech, braille (nothing in AgrOS's session starts them)
    smbclient nmap wvdial bind lynx ntp irssi lftp ldns tcpdump  # rescue disk network tools (the installer: curl, timesyncd)
    vim micro mc                            # editors besides nano
    opendesktop-fonts                       # a second Chinese font (Noto CJK covers the installer's language list)
    clonezilla partclone partimage testdisk ddrescue  # disk backup and rescue
    cloud-init                              # cloud server setup, never enabled
    cachyos-cli-installer-new               # CachyOS's text installer (it installs CachyOS, not AgrOS)
    edk2-shell                              # the UEFI Shell boot entry
    nvme-cli sg3_utils sdparm               # disk admin tools (the installer's partitioning: kpmcore, smartmontools)
    darkhttpd imwheel                       # Arch's test web server; an X11 mouse-wheel tool (the session is Wayland)
    gcc                                     # the installer's CPU check needed it until 2026-04 (now ld.so's own)
)
# The list read as mkarchiso reads it: a comment after a name, blanks around it. named <ERE>: a package in it matches;
# drop <ERE>: the lines naming one that does, gone
named() { re="^($1)\$" awk '{ sub(/#.*/, ""); gsub(/[[:blank:]]/, "") } $0 ~ ENVIRON["re"] { f = 1 } END { exit !f }' "$list"; }
drop() {
    re="^($1)\$" awk '{ l = $0; sub(/#.*/, "", l); gsub(/[[:blank:]]/, "", l) } l !~ ENVIRON["re"]' "$list" >"$list.new"
    cat "$list.new" >"$list" && rm "$list.new"
}
gone=() missing=()
for n in "${leave_out[@]}"; do
    if named "${n//./\\.}"; then drop "${n//./\\.}"; gone+=("$n"); else missing+=("$n"); fi
done
msg2 "Left out of the live ISO: %s" "${gone[*]:-nothing}"
((${#missing[@]} == 0)) || msg2 "Not in CachyOS's list any more (renamed or dropped?): %s (agros-trim.sh)" "${missing[*]}"

# Files inside packages the live session never uses, never unpacked (NoExtract, in the build's pacman.conf: the live
# system's own, airootfs/etc/pacman.conf, and so installed systems, get whole packages): the font styles nothing names
# (foot.ini's "JetBrains Mono Nerd Font" and group.lua's "JetBrains Mono NF" are the JetBrainsMonoNerdFont-* files,
# the shell's "CaskaydiaCove NF" the CaskaydiaCoveNerdFont-* ones, every icon "Material Symbols Rounded") and
# Hyprland's own wallpapers (Caelestia's dots set disable_hyprland_logo; Caelestia draws its own); the programs'
# translations (the live system is LANG=C.UTF-8, airootfs/etc/locale.conf: they'd never be read), but the installer's
# and those it may show (Calamares's Python modules', kpmcore's and KDE's, Qt's, the keyboard layouts' names); man and
# info pages (no man or info on the ISO to read them); docs and help pages (fish's kept: its `help` opens them). A
# pattern that matches nothing any more (a package renamed its files) just leaves them in: a bigger ISO, nothing broken.
# (pacman: a file's last matching pattern decides, `!` unpacks it after all, and * matches / too: each `!` after its
# pattern)
unused=(
    'usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-*' 'usr/share/fonts/TTF/JetBrainsMonoNerdFontPropo-*'
    'usr/share/fonts/TTF/JetBrainsMonoNL*'
    'usr/share/fonts/TTF/CaskaydiaCoveNerdFontMono-*' 'usr/share/fonts/TTF/CaskaydiaCoveNerdFontPropo-*'
    'usr/share/fonts/TTF/MaterialSymbolsOutlined*' 'usr/share/fonts/TTF/MaterialSymbolsSharp*'
    'usr/share/hypr/wall*.png'
)
no_extract=(
    'usr/share/locale/*' '!usr/share/locale/locale.alias' '!usr/share/locale/*/LC_MESSAGES/calamares*'
    '!usr/share/locale/*/LC_MESSAGES/k*' '!usr/share/locale/*/LC_MESSAGES/*_qt.qm'
    '!usr/share/locale/*/LC_MESSAGES/libplasma*' '!usr/share/locale/*/LC_MESSAGES/xkeyboard-config*'
    'usr/share/man/*' 'usr/share/info/*'
    'usr/share/doc/*' '!usr/share/doc/fish/*' 'usr/share/help/*' 'usr/share/gtk-doc/*'
    "${unused[@]}"
    # (NVIDIA's ray tracing (OptiX) and DLSS (NGX, and its Wine/Proton side): for games and 3D renderers only, none on
    # the live system, and no display library of the driver loads them; installed systems get the whole driver)
    'usr/lib/libnvoptix.so*' 'usr/share/nvidia/nvoptix.bin' 'usr/lib/libnvidia-ngx*' 'usr/bin/nvidia-ngx-updater'
    'usr/lib/nvidia/wine/*'
    # (Noto CJK's serif and its lightest and heaviest sans weights: nothing on the live system asks for them, and the
    # installer's Chinese, Japanese and Korean names keep Regular, Medium and Bold)
    'usr/share/fonts/noto-cjk/NotoSerifCJK-*' 'usr/share/fonts/noto-cjk/NotoSansCJK-Thin.ttc'
    'usr/share/fonts/noto-cjk/NotoSansCJK-Light.ttc' 'usr/share/fonts/noto-cjk/NotoSansCJK-DemiLight.ttc'
    'usr/share/fonts/noto-cjk/NotoSansCJK-Black.ttc'
    # (firmware for Marvell's network switch chips, not a PC's; nouveau's older GSP firmware, 535: it loads 570.144
    # first, kept)
    'usr/lib/firmware/mrvl/prestera/*' 'usr/lib/firmware/nvidia/*-535.113.01.bin*'
    # (C and C++ headers and static libraries: no compiler on the live system, gcc left out above)
    'usr/include/*' 'usr/lib/*.a'
    # (the pointer's 11 other Bibata styles: the desktop's is Bibata-Modern-Ice, agros's hypr-vars.lua)
    'usr/share/icons/Bibata-*' '!usr/share/icons/Bibata-Modern-Ice/*'
    # (CUDA's own compilers and debugger, and Vulkan SC (for safety-critical systems): only libcuda loads them, to build
    # or debug compute kernels, none on the live system; the display libraries and libcuda itself kept)
    'usr/lib/libnvidia-nvvm*' 'usr/lib/libnvidia-tileiras*' 'usr/lib/libcudadebugger*' 'usr/lib/libnvidia-vksc-core*'
    'usr/share/vulkansc/icd.d/nvidia_icd_vksc.json'
)
# Installed systems: the same, but what they use kept: their translations (any language can be picked), man pages
# (CachyOS's base has man), HPLIP's docs (its toolbox's Help button). In the installed system's pacman.conf
# (airootfs/etc/pacman-more.conf, the installer's copy before the first package), marked "# agros-iso": agros-system's
# install swaps it for its Include of the same list (agros's packages/agros-system/agros-noextract.conf: keep the two
# the same)
installed=(
    'usr/share/doc/*' '!usr/share/doc/fish/*' '!usr/share/doc/hplip*/*' 'usr/share/help/*' 'usr/share/gtk-doc/*'
    "${unused[@]}"
)
# add_noextract <pacman.conf> <patterns> <where, for the log>
# (right under [options]: at the file's end it would be under the last repo's section, where pacman ignores it)
add_noextract() {
    if [[ $(grep -c '^\[options\]$' "$1" 2>/dev/null) == 1 ]]; then
        sed -i "/^\[options\]\$/a NoExtract = $2" "$1"
        msg2 "Not unpacked %s" "$3"
    else
        msg2 "Every file unpacked %s: no single [options] in %s (agros-trim.sh)" "$3" "$1"
    fi
}
add_noextract "$p/pacman.conf" "${no_extract[*]}" \
    "in the live ISO: unused fonts, cursors, firmware and NVIDIA libraries, Hyprland's wallpapers, translations, man pages, docs, headers"
add_noextract "$p/airootfs/etc/pacman-more.conf" "${installed[*]} # agros-iso" \
    "on installed systems: unused font styles, Hyprland's wallpapers, docs"

boot=(grub/grub.cfg grub/loopback.cfg syslinux/archiso_sys-linux.cfg syslinux/archiso_pxe-linux.cfg)
keep_lts() { msg2 "The LTS kernel kept in the live ISO: %s (agros-trim.sh)" "$1"; exit 0; }
for f in "${boot[@]}"; do [[ -f $p/$f ]] || keep_lts "$f is gone"; done
for f in grub/grub.cfg grub/loopback.cfg; do
    grep -q "^menuentry .*--id 'cachyos-lts' {\$" "$p/$f" || keep_lts "no LTS entry in $f"
done
# (and no other menu file boots it, mkarchiso copying every grub/*.cfg and syslinux/*.cfg: one CachyOS adds, or its
# entries moved there, would boot a kernel gone from the ISO)
for f in "$p"/grub/*.cfg "$p"/syslinux/*.cfg; do
    [[ -f $f && " ${boot[*]} " != *" ${f#"$p"/} "* ]] || continue
    ! grep -q 'linux-cachyos-lts' "$f" || keep_lts "${f#"$p"/} boots it too"
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
    # (only those entries gone: one whose end isn't where it was, a closing brace or blank line CachyOS changed, took
    # the entries after it too, the fallback ones)
    entries="^[[:blank:]]*\(menuentry\|label\)[[:blank:]]"
    going=$(grep -c "^menuentry .*--id .cachyos-lts. {\$\|^LABEL cos64cur\$" "$p/$f" || true)
    (($(grep -ci "$entries" "$p/$f" || true) - $(grep -ci "$entries" "$tmp/${f##*/}" || true) == going)) ||
        keep_lts "$f: an entry's end isn't where it was (the entries after it would go with it)"
done
if left=$(grep -l 'cachyos-lts' "$tmp"/* | paste -sd' ') && [[ -n $left ]]; then
    keep_lts "still named in $left after the changes"
fi
grep -q 'vmlinuz-linux-cachyos ' "$tmp/grub.cfg" || keep_lts "no main-kernel entry left in grub.cfg"
# (every kernel the menus boot after the changes is one the ISO still has: an LTS file under a name this doesn't know,
# renamed to a kernel that doesn't exist, keeps the LTS kernel instead)
for k in $(grep -oh 'vmlinuz-[A-Za-z0-9._-]*\|initramfs-[A-Za-z0-9._-]*\.img' "$tmp"/* | sed 's/^vmlinuz-//; s/^initramfs-//; s/\.img$//' | sort -u); do
    [[ $k == linux-cachyos-lts* ]] || named "${k//./\\.}" || keep_lts "a boot entry would boot $k, which isn't in the ISO"
done
for f in "${boot[@]}"; do cat "$tmp/${f##*/}" >"$p/$f"; done
drop 'linux-cachyos-lts(-.*)?'
msg2 "Left out of the live ISO: the LTS kernel (its boot entries boot the main kernel)"
