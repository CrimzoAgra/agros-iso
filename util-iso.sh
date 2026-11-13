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

error_function() {
    if [[ -p $logpipe ]]; then
        rm "$logpipe"
    fi
    # first exit all subshells, then print the error
    if (( ! BASH_SUBSHELL )); then
        error "A failure occurred in %s()." "$1"
        plain "Aborting..."
    fi
    umount_fs
    umount_img
    exit 2
}

run_safe() {
    local restoretrap func="$1"
    set -e
    set -E
    restoretrap=$(trap -p ERR)
    trap 'error_function $func' ERR

    if ${verbose}; then
        run_log "$func"
    else
        "$func"
    fi

    eval $restoretrap
    set +E
    set +e
}

check_umount() {
    if mountpoint -q "$1"; then
        umount -l "$1"
    fi
}

trap_exit() {
    local sig=$1; shift
    error "$@"
    umount_fs
    trap -- "$sig"
    kill "-$sig" "$$"
}

generate_motd() {
    cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/motd
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
    mkdir -p ${src_dir}/archiso/airootfs/etc/pacman.d
    local _mirrorlist_url="https://github.com/CachyOS/CachyOS-PKGBUILDS/raw/master/cachyos-mirrorlist/cachyos-mirrorlist"

    # (-f and through a .tmp: an error page or an empty file never becomes the live system's mirror list)
    local _f=${src_dir}/archiso/airootfs/etc/pacman.d/cachyos-mirrorlist
    curl -fsSL "${_mirrorlist_url}" -o "$_f.tmp" && mv "$_f.tmp" "$_f"
}

change_grub_version() {
    local _version="$1"
    # (the build's copy, both menus: it changed the repo's grub.cfg at every build, and loopback.cfg said "GIT")
    sed -i "s/CACHYOS_VERSION=\".*\"/CACHYOS_VERSION=\"${_version}\"/" ${work_dir}/archiso/grub/{grub,loopback}.cfg
}

generate_environment() {
    local _profile="$1"
    if [ "$_profile" == "desktop" ]; then
        cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/environment
ZPOOL_VDEV_NAME_PATH=1
EOF
    fi
}

generate_version_tag() {
    local _profile="$1"
    local _version="$2"
    if [ "$_profile" == "desktop" ]; then
        echo "${_version}" > ${src_dir}/archiso/airootfs/etc/version-tag
    fi
}

generate_edition_tag() {
    local _edition="$1"
    echo "${_edition}" > ${src_dir}/archiso/airootfs/etc/edition-tag
}

modify_mkarchiso() {
    local _is_hack_applied="$(grep -q 'archlinux-keyring-wkd-sync.timer' /usr/bin/mkarchiso; echo $?)"
    if [ $_is_hack_applied -ne 0 ]; then
        msg "Patching mkarchiso with disabled arch keyrings timer..."

        sudo sed 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' -i /usr/bin/mkarchiso
    else
        msg "mkarchiso is already patched!"
    fi
    # The ISO's package list read from its package database with no repos set: through the live system's own
    # pacman.conf (--sysroot) it warned that the keyring, made at boot, isn't there yet
    if grep -q 'pacman -Q --sysroot "${pacstrap_dir}"' /usr/bin/mkarchiso; then
        msg "Patching mkarchiso's package list..."
        sudo sed -i 's|pacman -Q --sysroot "${pacstrap_dir}"|pacman -Q --config /dev/null --dbpath "${pacstrap_dir}/var/lib/pacman"|g' /usr/bin/mkarchiso
    fi
}

prepare_profile(){
    profile=$1

    info "Profile: [%s]" "${profile}"

    _iso_version="$(date +%y%m%d)"  # (the boot menus get it in run_build, on the build's copy)

    # Fetch up-to-date version of CachyOS repo mirrorlist
    fetch_cachyos_mirrorlist

    # mask cachyos-rate-mirrors timer
    ln -sf /dev/null ${src_dir}/archiso/airootfs/etc/systemd/system/cachyos-rate-mirrors.timer

    generate_motd

    rm -f ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    if [ "$profile" == "desktop" ]; then
        cp ${src_dir}/archiso/packages_desktop.x86_64 ${src_dir}/archiso/packages.x86_64
        # AgrOS: greetd logs the live user straight into AgrOS's Hyprland session (/etc/greetd/config.toml)
        ln -sf /usr/lib/systemd/system/greetd.service ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    else
        die "Unknown profile: [%s]" "${profile}"
    fi

    generate_environment "${profile}"

    # Write out version to be able to check ISO version
    generate_version_tag "${profile}" "${_iso_version}"

    # Write out edition to be able to check ISO edition
    generate_edition_tag "${profile}"

    iso_file=$(gen_iso_fn).iso
}

run_build() {
    prepare_profile "$1"
    local _profile="$1"

    msg "Prepare [work: ${work_dir}, out: ${outFolder}]"

    if $verbose; then
        msg2 "Making mkarchiso verbose"
        sudo sed -i 's/quiet="y"/quiet="n"/g' /usr/bin/mkarchiso
    fi

    if $clean_first; then
        msg2 "Deleting the build folder if one exists - takes some time"
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
    fi

    msg2 "Copying the Archiso folder to build work"
    mkdir -p ${work_dir}
    # (the old copy gone first: kept by -c, cp put the new profile inside it, archiso/archiso, and the old one was built)
    rm -rf ${work_dir}/archiso
    cp -r "${src_dir}/archiso" "${work_dir}/archiso"
    change_grub_version "${_iso_version}"
    # AgrOS: a fast test build compresses with zstd (xz, for releases, takes every core for most of the build)
    if $fast; then
        msg2 "Fast build: zstd compression"
        sed -i "s/^airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6' '-b' '1M')/" \
            ${work_dir}/archiso/profiledef.sh
        sed -i 's/^COMPRESSION=.*/COMPRESSION="zstd"/' ${work_dir}/archiso/airootfs/etc/mkinitcpio.conf.d/archiso.conf
    fi

    msg "Start [Build ISO]"

    # insert removal of archlinux keyrings timer on the ISO before pack
    modify_mkarchiso

    [ -d "$outFolder/$_profile" ] || mkdir -p "$outFolder/$_profile"
    cd ${work_dir}/archiso/
    # AgrOS: at the lowest CPU and disk priority, so the desktop stays usable meanwhile, and on half the CPU at most
    # (cpu_share, -a for all of it): every core flat out for the whole build ran the CPU at 86 °C with the fan at full
    # (no limit with -a, or with no systemd to set one: GitHub's container)
    local limit=()
    [[ ${cpu_share:-50} -lt 100 && -d /run/systemd/system ]] &&
        limit=(systemd-run --quiet --scope -p CPUQuota=$(( $(nproc) * ${cpu_share:-50} ))%)
    sudo "${limit[@]}" nice -n 19 ionice -c 3 mkarchiso -v -w ${work_dir} -o "$outFolder/$_profile" ${work_dir}/archiso/
    sudo chown "${SUDO_USER:-$USER}" "$outFolder"  # (under sudo, $USER is root)

    cp ${work_dir}/iso/arch/pkglist.x86_64.txt "$outFolder/$_profile/$(gen_iso_fn).pkgs.txt"
    # (whatever date mkarchiso named it with: a build past midnight, or its build_date kept by -c, is another day's)
    local _built=("$outFolder/$_profile"/agros-????.??.??-x86_64.iso)
    [[ ${#_built[@]} == 1 && -f ${_built[0]} ]] || die "mkarchiso's ISO not found (or several) in $outFolder/$_profile"
    mv "${_built[0]}" "$outFolder/$_profile/${iso_file}"

    msg "Done [Build ISO] ${iso_file}"
    msg "Finished building [%s]" "${_profile}"

    cd "$outFolder/$_profile"
    # This build's ISO only (the older ones in the folder have theirs: it went through each of them, every build)
    rm -f "${iso_file}.sig"
    create_chksums "${iso_file}"
    sign_with_key "${iso_file}"
    show_elapsed_time "${FUNCNAME}" "${timer_start}"
    if [[ "$build_in_ram" == "true" && "$remove_build_dir" == "false" ]]; then
        msg "!!! Remember to remove $work_dir !!!"
        msg2 "sudo rm -rf $work_dir"
    fi
    if [[ "$remove_build_dir" == "true" ]]; then
        msg "Automatically removing build directory ($work_dir)..."
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
        msg2 "Removed"
    fi
}

gen_iso_fn(){
    local vars=() name
    vars+=("agros")
    [[ -n ${profile} ]] && vars+=("${profile}")

    vars+=("linux")
    vars+=("$(date +%y%m%d)")

    for n in ${vars[@]}; do
        name=${name:-}${name:+-}${n}
    done

    echo $name
}
