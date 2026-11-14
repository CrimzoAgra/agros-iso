#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

get_timer(){
    date +%s
}

# $1: start timer
elapsed_time(){
    echo "$1 $(get_timer)" | awk '{ printf "%0.2f",($2-$1)/60 }'
}

show_elapsed_time(){
    info "Time %s: %s minutes" "$1" "$(elapsed_time "$2")"
}

# What the build needs (and git: it copies only the profile's tracked files), installed if missing.
# (from Arch's repos with pacman: yay and trizen, tried before, refuse to run as root, as the build is. Only the host's
# tools: squashfs-tools comes with archiso, and mkinitcpio-archiso goes into the ISO from its package list; grub is an
# optional dependency of archiso that its uefi.grub boot mode needs)
check_requirements(){
    local missing
    missing=$(pacman -T archiso git grub) || true
    if [[ -n $missing ]]; then
        msg "Installing %s" "${missing//$'\n'/ }"
        # shellcheck disable=SC2086
        sudo pacman -S --needed --noconfirm $missing ||
            die "Missing build tools: sudo pacman -S %s" "${missing//$'\n'/ }"
    fi
    # The build edits a copy of mkarchiso; older checkouts edited Arch's own in place, and that one, edited again, isn't
    # the mkarchiso the build expects
    # (its mismatches are warnings, on stderr; read whole, not with grep -q: under pipefail an early exit fails the pipe)
    if grep -q '/usr/bin/mkarchiso (.*\(checksum\|Size\) mismatch)' <<<"$(LC_ALL=C pacman -Qkk archiso 2>&1)"; then
        die "/usr/bin/mkarchiso was edited (an older checkout's build did that): restore it with sudo pacman -S archiso"
    fi
}

# The fingerprint of the first key in a key file (agros.asc): the one place AgrOS's key is named, for the build's
# signature and GitHub's pacman keyring. (Through a throwaway gpg home: as root, it made root's ~/.gnupg)
key_fpr() {
    local h; h=$(mktemp -d)
    gpg --homedir "$h" --batch --with-colons --show-keys "$1" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }'
    rm -rf "$h"
}

# Where the build puts a profile's ISOs (out/<profile>), and what upload-iso.sh and testiso.sh take when given none
iso_out_dir() {
    echo "$src_dir/out/${1:-desktop}"
}

# The newest ISO in a folder [default: iso_out_dir's]
newest_iso() {
    # shellcheck disable=SC2012
    ls -t "${1:-$(iso_out_dir)}"/*.iso 2>/dev/null | head -n1
}

# The user who started it: under sudo, the one who ran sudo (whose keyring, SSH key, home and config these are)
invoking_user() {
    echo "${SUDO_USER:-$(id -un)}"
}

# Run as root by sudo, by another user: someone to switch back to
run_by_sudo() {
    [[ $EUID -eq 0 && -n ${SUDO_USER:-} && $SUDO_USER != root ]]
}

# A command as invoking_user, with their home: run_by_sudo, switched back to them; otherwise as it is
as_invoking_user() {
    if run_by_sudo; then
        sudo -u "$SUDO_USER" -H "$@"
    else
        "$@"
    fi
}

# Whether $1.sig is a good signature of $1 by AgrOS's key (agros.asc): checked against that key alone, through gpgv
# with a keyring of agros.asc only, so a good signature by any other key (in whoever's keyring) doesn't pass, and the
# signer is matched by fingerprint (VALIDSIG: the signing key's, or its primary key's)
verify_agros_sig() {
    local h fpr st
    fpr=$(key_fpr "$src_dir/agros.asc")
    [[ -n $fpr && -f $1.sig ]] || return 1
    h=$(mktemp -d)
    gpg --homedir "$h" --batch --dearmor -o "$h/agros.gpg" "$src_dir/agros.asc" 2>/dev/null &&
        st=$(LC_ALL=C gpgv --keyring "$h/agros.gpg" --status-fd 1 "$1.sig" "$1" 2>/dev/null) || st=
    rm -rf "$h"
    awk -v f="$fpr" '$1 == "[GNUPG:]" && $2 == "VALIDSIG" && ($3 == f || $NF == f) { ok = 1 } END { exit !ok }' <<<"$st"
}

create_chksums() {
    msg2 "creating checksums for [%s]" "$1"
    sha1sum "$1" > "$1".sha1
    sha256sum "$1" > "$1".sha256
}

# Signed with AgrOS's key, the one in agros.asc (its packages' key, agros-keyring's), always: upload-iso.sh refuses a .sig
# by any other key (verify_agros_sig), so a makepkg.conf GPGKEY isn't read (another key's .sig couldn't go up; AgrOS's
# own is the same signature). From the keyring of whoever started the build (run with sudo: theirs, not root's)
sign_with_key() {
    [[ -e $1 ]] || die "%s does not exist!" "$1"

    local key; key=$(key_fpr "${src_dir}/agros.asc")
    # (an empty key, no agros.asc, would list every key and pass)
    if [[ -z $key ]] || ! as_invoking_user gpg --list-secret-keys "$key" >/dev/null 2>&1; then
        warning "Not signed: AgrOS's key %s (agros.asc) isn't in %s's keyring" "$key" "$(invoking_user)"
        return 0
    fi

    msg2 "signing [%s] with key %s" "${1##*/}" "$key"
    rm -f "$1".sig
    # (failed, as the missing key: a warning, not set -e's "unknown error" after a finished ISO, which skipped -w and -u;
    # upload-iso.sh --signed still refuses it unsigned)
    if ! as_invoking_user gpg --batch --detach-sign --use-agent -u "$key" "$1"; then
        rm -f "$1".sig
        warning "Not signed: gpg couldn't sign with AgrOS's key %s (passphrase or pinentry not reached?)" "$key"
    fi
}
