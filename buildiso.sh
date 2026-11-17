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

set -e
src_dir=$(dirname "$(readlink -f "$0")")  # (the repo, wherever it's run from)
# (the build's output in English; set here, not in util-msg.sh: testiso.sh's VM window would be in English too)
export LC_MESSAGES=C
export LANG=C
[[ -r ${src_dir}/util-msg.sh ]] && source "${src_dir}/util-msg.sh"
import "${src_dir}/util.sh"

# setting of the general parameters
work_dir="${src_dir}/build"

build_list_iso="desktop"
clean_first=true
build_in_ram=false
remove_build_dir=false
fast=false
upload=false

usage() {
    echo "Usage: ${0##*/} [options]"
    echo '    -c                 Resume a stopped build: keep its work dir (not after a finished one)'
    echo '    -r                 Build in RAM (in /tmp) if it has 14GB free, or else on disk'
    echo '    -w                 Remove build directory (not the ISO) after ISO file is built'
    echo '    -f                 Fast test build: a lower zstd level (quicker, a bigger ISO)'
    echo '    -a                 Use all of the CPU (by default the build gets half: cooler and quieter)'
    echo '    -u                 Upload the ISO to SourceForge once it is built (upload-iso.sh, as the sudo user)'
    echo "    -p <profile>       Buildset or profile [default: ${build_list_iso}]"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit "$1"
}

opts='p:chrwfau'

while getopts "${opts}" arg; do
    case "${arg}" in
        c) clean_first=false ;;
        p) build_list_iso="$OPTARG" ;;
        r) build_in_ram=true ;;
        w) remove_build_dir=true ;;
        f) fast=true ;;
        a) cpu_share=100 ;;
        u) upload=true ;;
        h) usage 0 ;;
        *) usage 1 ;;  # (getopts has said what's wrong)
    esac
done

shift $((OPTIND - 1))
(( $# == 0 )) || { error "unexpected argument: %s" "$1"; usage 1; }
# (checked here, before the old work dir is deleted and the mirror list downloaded: desktop is the one profile)
[[ $build_list_iso == desktop ]] || die "Unknown profile: [%s]" "$build_list_iso"
# (a test build past the upstream gate is never published: refused now, not after the whole build)
[[ ${AGROS_UNGATED:-} != 1 || $upload != true ]] || die "AGROS_UNGATED builds a test ISO, which isn't uploaded: leave out -u"
# (-c resumes a stopped build in build/: a RAM build's folder is a new one each time, nothing to resume there, and with
# too little room for RAM it would have resumed whatever stale build build/ held)
[[ $clean_first == true || $build_in_ram != true ]] || die "-c resumes a build stopped in build/: not with -r"
# (and AgrOS's commands for Calamares: a $ in them, an ISO whose installer never opens; before anything's set up)
check_calamares_commands

timer_start=$(get_timer)

import "${src_dir}/util-iso.sh"
import "${src_dir}/util-iso-mount.sh"

# (the traps before anything is made: a stop from here on, a wait or a failure, leaves nothing behind, a RAM folder
# included)
for sig in TERM HUP QUIT; do
    trap "trap_exit $sig \"$(gettext "%s signal caught. Exiting...")\" \"$sig\"" "$sig"
done
trap 'trap_exit INT "$(gettext "Aborted by user! Exiting...")"' INT
# (no ERR trap: set -e stops the build at a failed command and the EXIT trap reports it; with both, and after a die,
# each failure was reported twice, "unknown error" too, and unmounted twice)
trap exit_trap EXIT

# Build ISO in RAM: quicker, and spares the disk. In /tmp (a tmpfs, at half the RAM by default) if it has room for the
# work folder: the live system unpacked (about 7.6 GB) and the ISO's files with the squashfs (about 3.3 GB). The ISO
# itself goes to out/. (A RAM size said nothing of /tmp's room: 24 GB of RAM is a 12 GB /tmp)
if [[ "$build_in_ram" == "true" ]]; then
    avail=$(df --output=avail -BG "${TMPDIR:-/tmp}" 2>/dev/null | tail -1 | tr -dc 0-9) || true
    if (( ${avail:-0} >= 14 )); then
        # (made here, empty and the build's user's alone: never deleted and made again, which another user could get to
        # first) (set only once made: work_dir "" for the traps' unmount would be every mount)
        ram_dir=$(mktemp -d --suffix="-agros-iso") || die "No folder could be made in %s for -r" "${TMPDIR:-/tmp}"
        work_dir=$ram_dir work_fresh=true
    else
        warning "Not building in RAM: %s has less than 14GB free (or its free space couldn't be read)" "${TMPDIR:-/tmp}"
        build_in_ram=false
    fi
fi

# -c resumes a stopped build: mkarchiso skips each step that left its marker in the work dir, so after a finished one
# (its last marker) it would make no ISO, and leave out any change to the profile
if [[ "$clean_first" == "false" && -e ${work_dir}/iso._build_iso_image ]]; then
    die "%s holds a finished build: -c only resumes a stopped one. Build without -c" "$work_dir"
fi

mkdir -p "${work_dir}"

check_requirements
check_gate
# (the installer's package list, against the same repos: a name CachyOS renamed or dropped, an install that fails)
check_netinstall

run_build "${build_list_iso}"
# (finished: the EXIT trap was only for a build that stops halfway, it said "unknown error" after every good one too)
trap - EXIT
[[ -z ${gate_dir:-} ]] || sudo rm -rf "$gate_dir"

# upload-iso.sh switches to the user who ran sudo itself (their SSH key, keyring and ~/.config/agros-iso/upload.conf).
# The build is done: a failed upload reports its own error (the EXIT trap is off by now)
if [[ "$upload" == "true" ]]; then
    "${src_dir}/upload-iso.sh" "$(iso_out_dir "$build_list_iso")/${iso_file}"
fi
