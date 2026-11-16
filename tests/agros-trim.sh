#!/usr/bin/env bash
# agros-trim.sh on copies of the profile's files (fixtures/profile: archiso/'s, copied; and the repo's own archiso/):
# the packages it leaves out, and only those; its NoExtract lines right under [options] in both pacman.conf files (none
# with no single [options]); the LTS kernel gone with its boot entries booting the main kernel, or kept, with every boot
# file as it was, when CachyOS's menus don't look as it expects. (What it does, not what it says: its log's wording
# isn't checked)
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
fx=$here/tests/fixtures/profile
boot=(grub/grub.cfg grub/loopback.cfg syslinux/archiso_sys-linux.cfg syslinux/archiso_pxe-linux.cfg)
n=0

# fresh [profile]: a new copy of the fixture profile (or of the files the trim reads from <profile>, an archiso/: its
# menus, both pacman.conf files and its package list as the build copies it), in
# $p, LF whatever the checkout's line endings; $b: the same, untouched, to compare with
fresh() {
    n=$((n + 1)) p=$t/p$n b=$t/b$n
    mkdir -p "$p"
    if [[ -n ${1:-} ]]; then
        (cd "$1" && cp --parents -t "$p" grub/*.cfg syslinux/*.cfg pacman.conf airootfs/etc/pacman-more.conf)
        cp "$1/packages_desktop.x86_64" "$p/packages.x86_64"
    else
        cp -r "$fx/." "$p/"
    fi
    find "$p" -type f -exec sed -i 's/\r$//' {} +
}
# trim: agros-trim.sh on $p ($b the copy before); it never fails on what it reads
trim() {
    rm -rf "$b" && cp -r "$p" "$b"
    local out
    out=$(bash "$here/agros-trim.sh" "$p" 2>&1) || fail "agros-trim.sh failed: $out"
}
list=packages.x86_64
# (its leave_out list, the names as written there)
leave_out=$(awk '/^leave_out=\($/ { on = 1; next } on && /^\)/ { exit } on { sub(/#.*/, ""); print }' "$here/agros-trim.sh" |
    tr -s ' \t' '\n\n' | sed '/^$/d' | sort)
[[ $(wc -l <<<"$leave_out") -gt 20 ]] && grep -qx occt <<<"$leave_out" || fail "agros-trim.sh's leave_out not read: $leave_out"

# extracted <conf> <path>: whether pacman unpacks <path> under <conf>'s NoExtract lines (pacman's rule: the last
# pattern matching it decides, a ! one unpacks; * matches / too; a # starts a comment)
extracted() {
    local pats pat r=0
    read -ra pats <<<"$(sed -n 's/^NoExtract *= *//p' "$1" | sed 's/#.*//' | paste -sd' ')"
    for pat in "${pats[@]}"; do
        # shellcheck disable=SC2053  # (the pattern unquoted: matched as one)
        if [[ $pat == !* ]]; then [[ $2 != ${pat#!} ]] || r=0; else [[ $2 != $pat ]] || r=1; fi
    done
    return $r
}
# under_options <conf>: its one NoExtract line, and right under [options]
under_options() {
    [[ $(grep -c '^NoExtract' "$p/$1") == 1 ]] || fail "$1: not one NoExtract line: $(grep '^NoExtract' "$p/$1")"
    grep -A1 -x '\[options\]' "$p/$1" | tail -1 | grep -q '^NoExtract = ' || fail "$1: NoExtract isn't right under [options]"
    # (the rest as it was: one line added)
    [[ $(diff "$b/$1" "$p/$1" | grep -c '^[<>]') == 1 ]] || fail "$1: more than the NoExtract line changed"
}
# lts_kept <case>: the LTS kernel kept, every boot file and the kernels in the list as they were, the rest of the trim
# done (occt left out)
lts_kept() {
    local f
    for f in "${boot[@]}"; do
        [[ ! -e $b/$f ]] || cmp -s "$b/$f" "$p/$f" || fail "[$1] $f changed: $(diff "$b/$f" "$p/$f" | head -5)"
    done
    [[ $(grep '^linux-' "$p/$list") == "$(grep '^linux-' "$b/$list")" ]] || fail "[$1] the list's kernels changed"
    ! grep -qx occt "$p/$list" || fail "[$1] occt not left out"
}
entries() { grep -ciE '^[[:blank:]]*(menuentry|label)[[:blank:]]' "$1" || true; }
# lts_gone: the LTS kernel's packages and entries gone, every entry left booting the main kernel, only the LTS ones
# gone from the menus
lts_gone() {
    ! grep -q '^linux-cachyos-lts' "$p/$list" || fail "LTS packages left: $(grep '^linux-cachyos-lts' "$p/$list")"
    local f k
    for k in linux-cachyos linux-cachyos-nvidia-open linux-cachyos-zfs; do
        grep -qx "$k" "$p/$list" || fail "$k gone from the list"
    done
    for f in "${boot[@]}"; do
        ! grep -q cachyos-lts "$p/$f" || fail "$f still names the LTS kernel: $(grep cachyos-lts "$p/$f")"
    done
    [[ $(entries "$p/grub/grub.cfg") == $(($(entries "$b/grub/grub.cfg") - 1)) ]] || fail "grub.cfg: not one entry less"
    [[ $(entries "$p/grub/loopback.cfg") == $(($(entries "$b/grub/loopback.cfg") - 1)) ]] || fail "loopback.cfg: not one entry less"
    [[ $(grep '^LABEL' "$p/syslinux/archiso_sys-linux.cfg" | paste -sd' ') == "LABEL cos64 LABEL cos64fb" ]] ||
        fail "BIOS entries: $(grep '^LABEL' "$p/syslinux/archiso_sys-linux.cfg" | paste -sd' ')"
    [[ $(entries "$p/syslinux/archiso_pxe-linux.cfg") == 3 ]] || fail "PXE entries not all kept"
    ! grep -q "current kernel" "$p/syslinux/archiso_sys-linux.cfg" || fail "the current-kernel entry or its comment left"
    # (the fallback entries, GRUB's and BIOS's, there and on the main kernel)
    grep -A3 "^menuentry .*--id 'cachyos-fallback' {" "$p/grub/grub.cfg" | grep -q 'vmlinuz-linux-cachyos .*nomodeset' ||
        fail "GRUB's fallback entry gone or not on the main kernel"
    grep -A9 '^LABEL cos64fb$' "$p/syslinux/archiso_sys-linux.cfg" | grep -qx 'LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux-cachyos' ||
        fail "the BIOS fallback entry not on the main kernel"
    # (every kernel the menus boot, in the ISO's list)
    for k in $(cat "${boot[@]/#/$p/}" | grep -o 'vmlinuz-[A-Za-z0-9._-]*\|initramfs-[A-Za-z0-9._-]*\.img' |
        sed 's/^vmlinuz-//; s/^initramfs-//; s/\.img$//' | sort -u); do
        grep -qx "$k" "$p/$list" || fail "a boot entry boots $k, not in the list"
    done
}

# The fixture: what's left out, only that (whole lines: names that start the same, and a commented one, stay); NoExtract
# in both files, under [options], with the patterns doing what they say; the LTS kernel gone
fresh
printf '%s\n' bind-tools vim-runtime occt-extra '#mc' >>"$p/$list"
trim
gone=$(comm -23 <(sort "$b/$list") <(sort "$p/$list") | paste -sd' ')
# shellcheck disable=SC2086  # (one name a line)
want=$(printf '%s\n' $leave_out linux-cachyos-lts linux-cachyos-lts-nvidia-open linux-cachyos-lts-zfs | sort | paste -sd' ')
[[ $gone == "$want" ]] || fail "gone from the list: $gone; meant to go: $want"
for k in bind-tools vim-runtime occt-extra '#mc'; do grep -qxF -- "$k" "$p/$list" || fail "$k left out too"; done
under_options pacman.conf
under_options airootfs/etc/pacman-more.conf
grep -q '^NoExtract = .* # agros-iso$' "$p/airootfs/etc/pacman-more.conf" || fail "pacman-more.conf's line not marked # agros-iso"
live=$p/pacman.conf inst=$p/airootfs/etc/pacman-more.conf
for x in usr/share/locale/de/LC_MESSAGES/coreutils.mo usr/share/man/man1/ls.1.gz usr/share/info/bash.info.gz \
    usr/share/doc/foot/README.md usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Bold.ttf usr/share/hypr/wall0.png \
    usr/lib/libnvoptix.so.1; do
    ! extracted "$live" "$x" || fail "the live ISO unpacks $x"
done
for x in usr/share/locale/locale.alias usr/share/locale/de/LC_MESSAGES/calamares-python.mo \
    usr/share/locale/de/LC_MESSAGES/kpmcore.mo usr/share/locale/de/LC_MESSAGES/xkeyboard-config.mo \
    usr/share/doc/fish/index.html usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf usr/bin/Hyprland; do
    extracted "$live" "$x" || fail "the live ISO leaves out $x"
done
for x in usr/share/locale/de/LC_MESSAGES/coreutils.mo usr/share/man/man1/ls.1.gz usr/share/doc/fish/index.html \
    usr/share/doc/hplip-3.25/index.html usr/lib/libnvoptix.so.1; do
    extracted "$inst" "$x" || fail "installed systems leave out $x"
done
for x in usr/share/doc/foot/README.md usr/share/fonts/TTF/MaterialSymbolsSharp.ttf usr/share/hypr/wall2.png; do
    ! extracted "$inst" "$x" || fail "installed systems unpack $x"
done
lts_gone

# The repo's own profile, as CachyOS's last merge left it: the same (else the trim no longer fits their menus: look)
fresh "$here/archiso"
trim
under_options pacman.conf
under_options airootfs/etc/pacman-more.conf
lts_gone

# Names CachyOS dropped: the rest left out
fresh
sed -i '/^occt$/d; /^imwheel$/d' "$p/$list"
trim
! grep -qx orca "$p/$list" || fail "orca not left out with occt missing"

# No single [options]: none, a second one, the file gone, or CRLF lines (pacman reads them; the line can't be placed):
# that file as it was, the other done
fresh
sed -i '/^\[options\]$/d' "$p/pacman.conf"
trim
cmp -s "$b/pacman.conf" "$p/pacman.conf" || fail "pacman.conf with no [options] changed"
under_options airootfs/etc/pacman-more.conf
lts_gone
fresh
echo '[options]' >>"$p/airootfs/etc/pacman-more.conf"
trim
cmp -s "$b/airootfs/etc/pacman-more.conf" "$p/airootfs/etc/pacman-more.conf" || fail "pacman-more.conf with two [options] changed"
under_options pacman.conf
fresh
rm "$p/airootfs/etc/pacman-more.conf"
trim
under_options pacman.conf
[[ ! -e $p/airootfs/etc/pacman-more.conf ]] || fail "a missing pacman-more.conf made"
fresh
sed -i 's/$/\r/' "$p/pacman.conf"
trim
cmp -s "$b/pacman.conf" "$p/pacman.conf" || fail "a CRLF pacman.conf changed"

# CachyOS's menus not as expected: the LTS kernel kept, every boot file as it was
fresh
sed -i "/--id 'cachyos-lts'/d" "$p/grub/grub.cfg"
trim
lts_kept "no LTS entry in grub/grub.cfg"
fresh
sed -i "/--id 'cachyos-lts'/d" "$p/grub/loopback.cfg"
trim
lts_kept "no LTS entry in grub/loopback.cfg"
fresh
rm "$p/syslinux/archiso_pxe-linux.cfg"
trim
lts_kept "syslinux/archiso_pxe-linux.cfg is gone"
fresh
sed -i 's/$/\r/' "$p/grub/grub.cfg"
trim
lts_kept "no LTS entry in grub/grub.cfg"
# (an LTS file under a name the trim doesn't know: renamed, it would be a kernel the ISO doesn't have)
fresh
echo "INITRD /x/initramfs-linux-cachyos-lts-new.img" >>"$p/syslinux/archiso_sys-linux.cfg"
trim
lts_kept "a boot entry would boot linux-cachyos-new, which isn't in the ISO"
# (the main kernel not in the ISO: renamed by CachyOS, or the list empty or all commented out)
fresh
sed -i '/^linux-cachyos$/d' "$p/$list"
trim
lts_kept "a boot entry would boot linux-cachyos, which isn't in the ISO"
for empty in '' '#'; do
    fresh
    sed -i "s/^/$empty/" "$p/$list"
    [[ -n $empty ]] || : >"$p/$list"
    trim
    cmp -s "$b/$list" "$p/$list" || fail "an empty list${empty:+ (all commented out)} changed"
    lts_kept "an empty list${empty:+ (all commented out)}"
done

# An entry's end not where it was (a blank line or closing brace CachyOS changed): the entries after it not taken
# with it (the BIOS fallback, GRUB's), the LTS kernel kept
fresh
sed -i '/^LABEL cos64cur$/,/^$/{/^$/d}' "$p/syslinux/archiso_sys-linux.cfg"
trim
grep -q '^LABEL cos64fb$' "$p/syslinux/archiso_sys-linux.cfg" || fail "the BIOS fallback entry went with the current-kernel one"
lts_kept "syslinux/archiso_sys-linux.cfg"
fresh
sed -i "/--id 'cachyos-lts' {/,/^}\$/s/^}\$/} /" "$p/grub/grub.cfg"
trim
grep -q "^menuentry .*--id 'cachyos-fallback' {" "$p/grub/grub.cfg" || fail "GRUB's fallback entry went with the LTS one"
lts_kept "grub/grub.cfg"

# Another menu file booting the LTS kernel (one CachyOS adds, or its entries moved there): kept, else that entry would
# boot a kernel gone from the ISO
fresh
printf 'LABEL cos64lts\nLINUX /%%INSTALL_DIR%%/boot/%%ARCH%%/vmlinuz-linux-cachyos-lts\n' >"$p/syslinux/archiso_sys-lts.cfg"
trim
lts_kept "syslinux/archiso_sys-lts.cfg"
grep -qx 'linux-cachyos-lts' "$p/$list" || fail "the LTS kernel left out while syslinux/archiso_sys-lts.cfg boots it"

# The list read as mkarchiso reads it: a comment after a name, blanks around it (a line CachyOS writes so): left out
# all the same, the LTS kernel's too, and the main kernel counted as in it
fresh
sed -i 's/^occt$/occt  # a stress test/; s/^vim$/  vim\t/; s/^linux-cachyos-lts$/linux-cachyos-lts # LTS/
    s/^linux-cachyos$/linux-cachyos # the main one/' "$p/$list"
trim
names=$(sed 's/#.*//; s/[[:blank:]]//g; /^$/d' "$p/$list")
for k in occt vim linux-cachyos-lts; do ! grep -qx "$k" <<<"$names" || fail "$k, written with a comment or blanks, not left out"; done
grep -qx linux-cachyos <<<"$names" || fail "linux-cachyos, written with a comment, gone"
! grep -q cachyos-lts "$p/grub/grub.cfg" || fail "the LTS kernel kept: the main kernel's line has a comment"

echo "ok agros-trim"
