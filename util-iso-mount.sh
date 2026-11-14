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

check_umount() {
    if mountpoint -q "$1"; then
        sudo umount "$1"
    fi
}

# What a stopped build left mounted in the work folder, the deepest first. The work folder's exact path or what's
# under it (it was matched as a pattern anywhere in the line: build/ matched any other build/ too); /proc/mounts writes
# a space as \040
umount_fs(){
    local i
    while IFS= read -r i; do
        info "umount folder: [%s]" "$i"
        check_umount "$i"
    done < <(awk -v d="${work_dir%/}" '{ gsub(/\\040/, " ", $2) } $2 == d || index($2, d "/") == 1 { print $2 }' /proc/mounts | sort -r)
}
