#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

disable_colors(){
    # (empty, not unset: upload-iso.sh and testiso.sh source this under set -u)
    ALL_OFF='' BOLD='' BLUE='' GREEN='' RED='' YELLOW=''
}

enable_colors(){
    # prefer terminal safe colored and bold text when tput is supported
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
    fi
    readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

if [[ -t 2 ]]; then
    enable_colors
else
    disable_colors
fi

msg() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
    local mesg=$1; shift
    printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

info() {
    local mesg=$1; shift
    printf "${YELLOW} -->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

# (on GitHub, also an annotation on the run: ::warning:: and ::error:: at a line's start)
warning() {
    local mesg=$1; shift
    printf "${GITHUB_ACTIONS:+::warning::}${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
    local mesg=$1; shift
    printf "${GITHUB_ACTIONS:+::error::}${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

cleanup() {
    exit "${1:-0}"
}

die() {
    (( $# )) && error "$@"
    # shellcheck disable=SC2034
    died=1  # (said what failed: buildiso.sh's exit trap doesn't add "unknown error")
    cleanup 255
}

import(){
    if [[ -r $1 ]]; then
        source "$1"
    else
        die "Could not import %s" "$1"
    fi
}
