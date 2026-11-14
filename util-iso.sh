#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# With -r, the way to free the RAM the work folder (about 11 GB) still holds: after a good build kept with it (no -w),
# and after a stopped one (it was only said after a good build)
ram_reminder() {
    if [[ "$build_in_ram" == "true" ]]; then
        warning "The work folder is still in RAM: sudo rm -rf %s" "$work_dir"
    fi
}

# What a stopped build leaves: nothing mounted
stopped() {
    umount_fs
    ram_reminder
}

# Before a build (not with -c) and after one with -w: unmounted first, what a stopped build left mounted
remove_work_dir() {
    umount_fs
    if [[ -d ${work_dir} ]]; then
        sudo rm -rf "${work_dir}"
    fi
}

# The profile into the work folder: only the files git tracks, so what an older checkout's build left in archiso/
# (root's generated files: packages.x86_64, etc/motd, a cachyos-rate-mirrors.timer mask, gdm/...) never reaches the
# ISO. Edits not committed yet are in; a new file once git-added (said below). Not a git checkout of its own (a
# download of the repo): all of archiso/
copy_profile() {
    local git=(git -C "$src_dir" -c safe.directory="$src_dir") files=() f untracked
    rm -rf "${work_dir}/archiso"
    if [[ $("${git[@]}" rev-parse --show-toplevel 2>/dev/null) == "$src_dir" ]]; then
        while IFS= read -r -d '' f; do
            # (deleted, not git rm'd yet: left out, as it's gone)
            [[ -e $src_dir/$f || -L $src_dir/$f ]] && files+=("$f")
        done < <("${git[@]}" ls-files -z -- archiso)
        (( ${#files[@]} )) || die "git tracks no files in %s/archiso" "$src_dir"
        (cd "$src_dir" && cp -P --parents -t "$work_dir" -- "${files[@]}")
        untracked=$("${git[@]}" ls-files --others --exclude-standard -- archiso)
        [[ -z $untracked ]] || warning "Left out of the ISO, git doesn't track them (git add a new file to have it in):\n%s" "$untracked"
    else
        warning "%s isn't a git checkout: all of archiso/ goes in, whatever else is in it" "$src_dir"
        cp -r "${src_dir}/archiso" "${work_dir}/archiso"
    fi
}

trap_exit() {
    local sig=$1; shift
    trap - EXIT  # (said here: not again, as an unknown error, on the way out)
    error "$@"
    stopped
    trap -- "$sig"
    kill "-$sig" "$$"
}

# A build that stopped halfway, reported once: die has said why, a failed command (set -e) hasn't
exit_trap() {
    (( ${died:-0} )) || error "An unknown error has occurred. Exiting..."
    stopped
}

generate_motd() {
    cat << 'EOF' > "${work_dir}/archiso/airootfs/etc/motd"
This ISO is based on CachyOS's live ISO, modified to provide the installation environment for [38;2;190;196;238mAgrOS[0m.
https://github.com/CrimzoAgra/agros

AgrOS Archiso Sources (a fork of CachyOS's):
https://github.com/CrimzoAgra/agros-iso

ArchLinux ISO Source:
https://gitlab.archlinux.org/archlinux/archiso

Calamares is used as GUI installer:
https://github.com/calamares/calamares

Live environment will start now and let you install [38;2;190;196;238mAgrOS[0m to disk.

Getting help: https://github.com/CrimzoAgra/agros/issues

Welcome to [38;2;190;196;238mAgrOS[0m!

[41m [41m [41m [40m [44m [40m [41m [46m [45m [41m [46m [43m [41m [44m [45m [40m [44m [40m [41m [44m [41m [41m [46m [42m [41m [44m [43m [41m [45m [40m [40m [44m [40m [41m [44m [42m [41m [46m [44m [41m [46m [47m [0m
EOF
}

fetch_cachyos_mirrorlist() {
    mkdir -p "${work_dir}/archiso/airootfs/etc/pacman.d"
    local _mirrorlist_url="https://github.com/CachyOS/CachyOS-PKGBUILDS/raw/master/cachyos-mirrorlist/cachyos-mirrorlist"

    # (-f and through a .tmp: an error page or an empty file never becomes the live system's mirror list. A die: in a
    # && list, set -e let a failed download through, and the ISO had no CachyOS mirror list)
    local _f="${work_dir}/archiso/airootfs/etc/pacman.d/cachyos-mirrorlist"
    curl -fsSL --retry 3 --retry-all-errors "${_mirrorlist_url}" -o "$_f.tmp" || die "CachyOS's mirror list couldn't be downloaded (%s)" "${_mirrorlist_url}"
    mv "$_f.tmp" "$_f"
}

change_grub_version() {
    local _version="$1"
    # (the build's copy, both menus: it changed the repo's grub.cfg at every build, and loopback.cfg said "GIT".
    # Checked: a menu whose line moved would have kept "GIT")
    local f
    for f in "${work_dir}"/archiso/grub/{grub,loopback}.cfg; do
        sed -i "s/CACHYOS_VERSION=\".*\"/CACHYOS_VERSION=\"${_version}\"/" "$f"
        grep -q "^CACHYOS_VERSION=\"${_version}\"\$" "$f" || die "The version isn't set in %s: its CACHYOS_VERSION line moved" "${f##*/}"
    done
}

generate_environment() {
    local _profile="$1"
    if [ "$_profile" == "desktop" ]; then
        cat << 'EOF' > "${work_dir}/archiso/airootfs/etc/environment"
ZPOOL_VDEV_NAME_PATH=1
EOF
    fi
}

generate_version_tag() {
    local _profile="$1"
    local _version="$2"
    if [ "$_profile" == "desktop" ]; then
        echo "${_version}" > "${work_dir}/archiso/airootfs/etc/version-tag"
    fi
}

generate_edition_tag() {
    local _edition="$1"
    echo "${_edition}" > "${work_dir}/archiso/airootfs/etc/edition-tag"
}

# A copy of Arch's mkarchiso for this build, with AgrOS's two changes (Arch's own file not touched):
# Arch's keyring timer off on the ISO (no Arch keyring refresh on a CachyOS system), and the ISO's package list read
# from its package database with no repos set (through the live system's pacman.conf, --sysroot, it warned that the
# keyring, made at boot, isn't there yet). Each checked: an archiso update that moves a line fails the build
modify_mkarchiso() {
    local m="${work_dir}/mkarchiso"
    sudo install -m755 /usr/bin/mkarchiso "$m"
    sudo sed -i 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' "$m"
    sudo sed -i 's|pacman -Q --sysroot "${pacstrap_dir}"|pacman -Q --config /dev/null --dbpath "${pacstrap_dir}/var/lib/pacman"|g' "$m"
    grep -q 'archlinux-keyring-wkd-sync.timer' "$m" && grep -q 'pacman -Q --config /dev/null --dbpath' "$m" &&
        ! grep -q 'pacman -Q --sysroot' "$m" || die "mkarchiso changed: AgrOS's edits to it no longer fit (util-iso.sh)"
}

# The generated files go into the build's copy of the profile (run_build makes it first), not the repo's: written as
# root, they were left in the repo, root's
prepare_profile(){
    profile=$1

    info "Profile: [%s]" "${profile}"

    # The build's time, taken once: the version (the boot menus get it in run_build, on the build's copy) and the ISO's
    # name (gen_iso_fn) are the same moment, also for a build started just before midnight
    _iso_stamp="$(date +%y%m%d-%H%M)"
    _iso_version="${_iso_stamp%-*}"

    # Fetch up-to-date version of CachyOS repo mirrorlist
    fetch_cachyos_mirrorlist

    # (cachyos-rate-mirrors.timer is kept off on the live system by a pacman hook, once its package has enabled it:
    # a mask made first failed that, "Failed to enable unit", in the build's log)

    generate_motd

    # (the one profile: buildiso.sh stops on any other before touching anything)
    cp "${work_dir}/archiso/packages_desktop.x86_64" "${work_dir}/archiso/packages.x86_64"
    # AgrOS: greetd logs the live user straight into AgrOS's Hyprland session (/etc/greetd/config.toml)
    ln -sf /usr/lib/systemd/system/greetd.service "${work_dir}/archiso/airootfs/etc/systemd/system/display-manager.service"

    generate_environment "${profile}"

    # Write out version to be able to check ISO version
    generate_version_tag "${profile}" "${_iso_version}"

    # Write out edition to be able to check ISO edition
    generate_edition_tag "${profile}"

    iso_file=$(gen_iso_fn).iso
}

run_build() {
    local _profile="$1" _out
    _out=$(iso_out_dir "$_profile")

    msg "Prepare [work: %s, out: %s]" "${work_dir}" "${_out}"

    if $clean_first; then
        msg2 "Deleting the build folder if one exists - takes some time"
        remove_work_dir
    fi

    msg2 "Copying the Archiso folder to build work"
    mkdir -p "${work_dir}"
    # (the old copy gone first: kept by -c, cp put the new profile inside it, archiso/archiso, and the old one was built)
    copy_profile
    prepare_profile "${_profile}"
    change_grub_version "${_iso_version}"
    # AgrOS: a fast test build compresses at a lower zstd level (bigger, quicker)
    if $fast; then
        msg2 "Fast build: zstd level 6"
        sed -i "s/^airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')/" \
            "${work_dir}/archiso/profiledef.sh"
        grep -q "^airootfs_image_tool_options=.*'-Xcompression-level' '6'" "${work_dir}/archiso/profiledef.sh" ||
            die "-f: profiledef.sh's airootfs_image_tool_options line moved, the zstd level wasn't lowered"
    fi

    msg "Start [Build ISO]"

    modify_mkarchiso

    [ -d "$_out" ] || mkdir -p "$_out"
    # (a partial one left by a stopped build, mkarchiso's name, root's: a later day's build found two below and died at
    # the very end. Finished ones are renamed to agros-<profile>-linux-..., which this doesn't match)
    sudo rm -f "$_out"/agros-????.??.??-x86_64.iso
    cd "${work_dir}/archiso/" || die "No profile in %s" "${work_dir}/archiso"
    # AgrOS: at the lowest CPU and disk priority, so the desktop stays usable meanwhile, and on half the CPU at most
    # (cpu_share, -a for all of it): every core flat out for the whole build ran the CPU at 86 °C with the fan at full
    # (no limit with -a, or with no systemd to set one: GitHub's container)
    local limit=()
    [[ ${cpu_share:-50} -lt 100 && -d /run/systemd/system ]] &&
        limit=(systemd-run --quiet --scope -p CPUQuota=$(( $(nproc) * ${cpu_share:-50} ))%)
    # (as root: archiso 91+ warns "Running as root is not advised" under sudo and can build rootless, through unshare,
    # but this build's work folder, unmounting and cleanup are root's; not switched without a build to test it on)
    sudo "${limit[@]}" nice -n 19 ionice -c 3 "${work_dir}/mkarchiso" -v -w "${work_dir}" -o "$_out" "${work_dir}/archiso/"
    # (out/ and out/desktop, made by root: the signature is written there as the user who ran sudo)
    sudo chown "$(invoking_user)" "${_out%/*}" "$_out"

    # (whatever date mkarchiso named it with: a build past midnight, or its build_date kept by -c, is another day's)
    local _built=("$_out"/agros-????.??.??-x86_64.iso)
    [[ ${#_built[@]} == 1 && -f ${_built[0]} ]] || die "mkarchiso's ISO not found (or several) in %s" "$_out"
    mv "${_built[0]}" "$_out/${iso_file}"
    cp "${work_dir}/iso/arch/pkglist.x86_64.txt" "$_out/${iso_file%.iso}.pkgs.txt"

    msg "Done [Build ISO] %s" "${iso_file}"
    msg "Finished building [%s]" "${_profile}"

    cd "$_out" || die "No %s" "$_out"
    # This build's ISO only (the older ones in the folder have theirs: it went through each of them, every build)
    rm -f "${iso_file}.sig"
    create_chksums "${iso_file}"
    sign_with_key "${iso_file}"
    show_elapsed_time "${FUNCNAME[0]}" "${timer_start}"
    if [[ "$remove_build_dir" == "true" ]]; then
        msg "Automatically removing build directory (%s)..." "$work_dir"
        remove_work_dir
        msg2 "Removed"
    else
        ram_reminder
    fi
}

gen_iso_fn(){
    local vars=() name
    vars+=("agros")
    [[ -n ${profile} ]] && vars+=("${profile}")

    vars+=("linux")
    # (and the time: a second ISO the same day got the first one's name, and replaced it on SourceForge)
    vars+=("${_iso_stamp}")

    for n in "${vars[@]}"; do
        name=${name:-}${name:+-}${n}
    done

    echo "$name"
}
