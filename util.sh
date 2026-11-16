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

# The upstream gate (agros's agros-gate.conf, update-gate on AgrOS's machines): the ISO built only with the versions of
# Hyprland and its libraries AgrOS's CI has approved (its list beside the [agros] repo, whose names are the gated ones),
# and a copy of those packages kept on it (/opt/agros/gate) for the installer to install, not whatever is newest on
# the day (agros-gate-install). gate_list: the approved list, fetched past GitHub Pages' cache (approved minutes ago,
# as a push starts this, it was served the old one); an empty or garbled one (an error page) stops the build rather
# than letting anything through, and so does one without a good signature by AgrOS's key beside it (agros-approved.sig,
# agros's CI signs it; verify_agros_sig: agros.asc alone), none or a bad one (a mirror or a network in between that
# changed it)
gate_list(){
    local server list stamp d
    # (fetched once a build: check_gate's fetch read by the build's later steps, all on the same list; a blip at the end
    # can't stop a finished build)
    if [[ -n ${gate_cache:-} && -s $gate_cache ]]; then cat "$gate_cache"; return 0; fi
    server=$(pacman-conf --config "$src_dir/archiso/pacman.conf" --repo agros Server | head -1)
    stamp=$(date +%s)
    d=$(mktemp -d) || die "No temporary folder for the approved list"
    if ! curl -fsS --connect-timeout 10 -m 30 --retry 3 --retry-all-errors -o "$d/agros-approved" "$server/agros-approved?t=$stamp"; then
        rm -rf "$d"
        die "AgrOS's approved upstream versions couldn't be fetched (%s/agros-approved)" "$server"
    fi
    if ! curl -fsS --connect-timeout 10 -m 30 --retry 3 --retry-all-errors -o "$d/agros-approved.sig" "$server/agros-approved.sig?t=$stamp" ||
        ! verify_agros_sig "$d/agros-approved"; then
        rm -rf "$d"
        die "AgrOS's approved upstream versions have no good signature by AgrOS's key (%s/agros-approved.sig)" "$server"
    fi
    list=$(cat "$d/agros-approved")
    rm -rf "$d"
    [[ -n $list ]] && ! grep -qvE '^[a-z0-9@._+-]+ [A-Za-z0-9.:_+~]+$' <<<"$list" ||
        die "AgrOS's approved upstream versions aren't a list of them (%s/agros-approved)" "$server"
    # (kept first: a list that can't be kept stops here, said, not silently after it was printed)
    [[ -z ${gate_cache:-} ]] || printf '%s\n' "$list" >"$gate_cache" || die "The approved list couldn't be kept in %s" "$gate_cache"
    printf '%s\n' "$list"
}
# gate_plan <list> [dir]: the gated packages the ISO gets ("name version"), its package list resolved with its own
# pacman.conf as mkarchiso installs it (a gated one the ISO doesn't have isn't looked at; the list read as mkarchiso
# reads it, comments after a name too); with <dir>, those packages alone downloaded there (not what they need: the ISO
# has that, and the installer's copy is only the gated set)
gate_plan(){
    local conf=$src_dir/archiso/pacman.conf tmp plan names
    # (in the build's own folder for these when there is one, beside its list: a stopped build removes it, stopped())
    if [[ -n ${gate_dir:-} ]]; then
        tmp=$gate_dir/db
        sudo rm -rf "$tmp"
        mkdir "$tmp" || die "No folder for the ISO's package lists in %s" "$gate_dir"
    else
        tmp=$(mktemp -d) || die "No temporary folder for the ISO's package lists"
    fi
    # (sudo: in CI the build runs as its user, root only for what needs it; a sync, even into a folder of its own, does)
    if ! sudo pacman -Sy --config "$conf" --dbpath "$tmp" --logfile /dev/null >/dev/null ||
        ! plan=$(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d;s/[[:blank:]]//g' "$src_dir/archiso/packages_desktop.x86_64" |
            sudo pacman -Sp --noconfirm --config "$conf" --dbpath "$tmp" --print-format '%n %v' - 2>/dev/null); then
        sudo rm -rf "$tmp"
        die "The ISO's packages couldn't be looked up (for the upstream gate)"
    fi
    plan=$(awk 'NR == FNR { gated[$1]; next } $1 in gated' <(printf '%s\n' "$1") <(printf '%s\n' "$plan"))
    if [[ -n ${2:-} && -n $plan ]]; then
        mapfile -t names < <(cut -d' ' -f1 <<<"$plan")
        sudo mkdir -p "$2"
        sudo pacman -Swdd --noconfirm --config "$conf" --dbpath "$tmp" --cachedir "$2" --logfile /dev/null -- "${names[@]}" >/dev/null ||
            { sudo rm -rf "$tmp"; die "The ISO's Hyprland packages couldn't be downloaded (for the installer's copy)"; }
    fi
    sudo rm -rf "$tmp"
    printf '%s\n' "$plan"
}
# gate_list_or_ungated: gate_list; with AGROS_UNGATED (a local test build) none is fine too, said ("" then: nothing
# gated, nothing copied for the installer)
gate_list_or_ungated(){
    if [[ ${AGROS_UNGATED:-} == 1 ]]; then
        # (none at check_gate: none for the whole build, said once; not one that came back mid-build, never checked)
        [[ -n ${gate_cache:-} && $(cat "$gate_cache" 2>/dev/null) == "#none" ]] && return 0
        ( gate_list ) 2>/dev/null && return 0
        warning "No approved list (AGROS_UNGATED): the ISO not checked, and no Hyprland copy for its installer"
        [[ -z ${gate_cache:-} ]] || echo "#none" >"$gate_cache"
    else
        gate_list
    fi
}
# gate_waits: what the ISO would get unapproved ("name version" lines)
gate_waits(){
    local list plan name ver
    # (each failure said where it happened, in its subshell: a bare die, so buildiso.sh's exit trap adds no "unknown
    # error")
    list=$(gate_list_or_ungated) || die
    [[ -n $list ]] || return 0
    # (not read through <(...): a die there only ends that subshell, and nothing checked passed as nothing waiting)
    plan=$(gate_plan "$list") || die
    while read -r name ver; do
        [[ -n $name ]] || continue
        grep -qxF -- "$name ${ver%-*}" <<<"$list" || echo "$name $ver"
    done <<<"$plan"
    return 0
}
# The build's own check (buildiso.sh): stopped when something waits, and the ISO already published stays the download.
# AGROS_UNGATED=1: built anyway (a local test build), with a warning
check_gate(){
    local waits
    # (the build's one fetch of the approved list, kept for its later steps, and the sync databases its plan reads: in a
    # folder of its own, the build's user's alone, its names not to be guessed; removed by the build's end or stopped())
    gate_dir=$(mktemp -d --tmpdir agros-gate.XXXXXX) || die "No temporary folder for the approved list"
    gate_cache=$gate_dir/list
    waits=$(gate_waits) || die
    [[ -n $waits ]] || return 0
    if [[ ${AGROS_UNGATED:-} == 1 ]]; then
        warning "Not checked by AgrOS's CI yet, built in all the same (AGROS_UNGATED): %s" "$(paste -sd, <<<"$waits")"
    else
        # (75: a wait, not a failure; the ISO workflow reads it as held, as its own gate step's. Said as a warning: on
        # GitHub an error is an error annotation on a run that ends green)
        warning "Not checked by AgrOS's CI yet: %s. The ISO waits for its next run (AGROS_UNGATED=1 builds it anyway)" "$(paste -sd, <<<"$waits")"
        died=1
        exit 75
    fi
}
# gate_fetch <dir>: those packages downloaded into the live system's files (the installer's copy)
gate_fetch(){
    local list
    list=$(gate_list_or_ungated) || die
    [[ -n $list ]] || return 0
    gate_plan "$list" "$1" >/dev/null || die
    # (built anyway, AGROS_UNGATED: the copy may be unapproved; the installer then puts it in only when its list says so)
    [[ ${AGROS_UNGATED:-} != 1 ]] || { sudo mkdir -p "$1" && sudo touch "$1/ungated"; }
}
# gate_verify <dir> <pkglist>: the copy only gated packages (the approved list's names), every gated one the built ISO
# has, at its versions (a mirror updated during the build: the installer would put in another Hyprland than the live
# system's), and those approved (checked again: check_gate's look was before the build's own download), else the build
# stops
gate_verify(){
    local f nv list name copied=
    list=$(gate_list_or_ungated) || die
    [[ -n $list ]] || return 0
    for f in "$1"/*.pkg.tar.*; do
        [[ -e $f && $f != *.sig ]] || continue
        nv=$(pacman -Qp "$f" 2>/dev/null) || die "Not a package in the installer's copy: %s" "$f"
        name=${nv%% *}
        awk -v n="$name" '$1 == n { found = 1 } END { exit !found }' <<<"$list" ||
            die "Not one of the gated packages in the installer's copy: %s" "$nv"
        grep -qxF -- "$nv" "$2" || die "The ISO's %s changed while it was built (its copy for the installer is %s): build again" "$name" "$nv"
        grep -qxF -- "${nv%-*}" <<<"$list" || [[ ${AGROS_UNGATED:-} == 1 ]] ||
            die "The ISO's %s isn't approved (a mirror updated since the check): build again" "$nv"
        copied+=" $name "
    done
    # (and none the ISO has missing from it)
    while read -r name _; do
        [[ $copied == *" $name "* ]] || die "The ISO's %s isn't in its installer's copy: build again" "$name"
    done < <(awk 'NR == FNR { gated[$1]; next } $1 in gated' <(printf '%s\n' "$list") "$2")
}

# AgrOS's commands for Calamares's shellprocess step (agros-calamares-config's) have no dollar sign: Calamares reads
# them as its own variables, and one it doesn't know stops the install. The installer checks it too, but only once it
# runs: an ISO whose installer never opens isn't built
check_calamares_commands(){
    local f=$src_dir/archiso/airootfs/usr/local/bin/agros-calamares-config found
    grep -q "shellprocess_greetd.conf\" <<'CONF'" "$f" || die "agros-calamares-config's command for Calamares not found"
    # (the heredoc's lines after its first, numbered as in the file)
    found=$(awk -v start="shellprocess_greetd.conf\" <<'CONF'" 'index($0, start) { on = 1; next } on && /^CONF$/ { on = 0 }
        on && /\$/ { print FILENAME ":" FNR ": " $0 }' "$f")
    [[ -z $found ]] || die "A dollar sign in agros-calamares-config's command for Calamares (it reads it as its own): %s" "$found"
}

# The fingerprint of the first key in a key file (agros.asc): the one place AgrOS's key is named, for the build's
# signature and GitHub's pacman keyring. (Through a throwaway gpg home: as root, it made root's ~/.gnupg)
key_fpr() {
    # (no temporary folder: no fingerprint, which every caller takes as no key)
    local h; h=$(mktemp -d) || return 0
    gpg --homedir "$h" --batch --with-colons --show-keys "$1" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }'
    rm -rf "$h"
}

# Where the build puts a profile's ISOs (out/<profile>), and what upload-iso.sh and testiso.sh take when given none
iso_out_dir() {
    echo "$src_dir/out/${1:-desktop}"
}

# The newest ISO in a folder [default: iso_out_dir's], a finished one (gen_iso_fn's name): not the one a stopped build
# left half-written under mkarchiso's (agros-YYYY.MM.DD-x86_64.iso), which testiso.sh booted
newest_iso() {
    # shellcheck disable=SC2012
    ls -t "${1:-$(iso_out_dir)}"/agros-*-linux-*.iso 2>/dev/null | head -n1
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
    h=$(mktemp -d) || return 1
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
    # (a test build past the upstream gate: AgrOS's key never vouches for it, whatever it's renamed to)
    if [[ ${AGROS_UNGATED:-} == 1 ]]; then
        warning "Not signed: a test build (AGROS_UNGATED)"
        return 0
    fi
    # (signed later, by another step: the ISO workflow's publish job, the key kept away from the build)
    if [[ -n ${AGROS_SIGN_LATER:-} ]]; then
        msg2 "not signed here: signed later (AGROS_SIGN_LATER)"
        return 0
    fi
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
