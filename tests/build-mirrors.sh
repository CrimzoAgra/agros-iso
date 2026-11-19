#!/usr/bin/env bash
# The build's pacman.conf (archiso/pacman.conf: mkarchiso's, the upstream gate's and check_netinstall's) has more than
# one server for CachyOS's repo: with mirror.cachyos.org alone, a moment it was down (HTTP 521, 2026-11-19) failed the
# whole ISO build. Read as pacman reads it where pacman-conf is there, else from the file
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
conf=$here/archiso/pacman.conf
if command -v pacman-conf >/dev/null; then
    servers=$(pacman-conf --config "$conf" --repo cachyos Server)
else
    servers=$(tr -d '\r' <"$conf" | awk '/^\[/ { on = ($0 == "[cachyos]") } on && sub(/^Server *= */, "")')
fi
[[ $(grep -c . <<<"$servers") -ge 2 ]] || fail "one server for [cachyos] in the build's pacman.conf: $servers"
[[ $(head -1 <<<"$servers") == https://mirror.cachyos.org/* ]] || fail "CachyOS's own server isn't the first: $servers"
echo "ok build-mirrors"
