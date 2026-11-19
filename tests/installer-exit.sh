#!/usr/bin/env bash
# calamares-online.sh when the installer itself ends, with the desktop's and the system's tools stubbed (nothing run as
# root, no notification reaching the desktop running the tests): gone by itself (a crash, a window the graphics never
# showed), said in its log with its status, its errors there too, and the script failing with it (its notification:
# the splash only closed, nothing else told the user); closed as usual (status 0), nothing said
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
script=$here/archiso/airootfs/usr/local/bin/calamares-online.sh
mkdir -p "$t/bin" "$t/run" "$t/home"
# (sudo: every root step passes, none run; the installer's window up at once, so the splash's closer ends; qs: the
# splash, up until closed, and Caelestia's bar answering)
printf '#!/bin/sh\nexit 0\n' >"$t/bin/sudo"
printf '#!/bin/sh\necho full\n' >"$t/bin/nmcli"
printf '#!/bin/sh\necho yes\n' >"$t/bin/timedatectl"
printf '#!/bin/sh\n[ "$1" = -j ] && echo '\''[{"class": "io.calamares.calamares"}]'\''\nexit 0\n' >"$t/bin/hyprctl"
printf '#!/bin/sh\n[ "$1" = -p ] || exit 0\nexec sleep 30\n' >"$t/bin/qs"
# (the installer: its status from $RC, a line on stderr)
printf '#!/bin/sh\necho "the installer: $*"\necho "qt.qpa.wayland: something went wrong" >&2\nexit "$RC"\n' \
    >"$t/bin/pkexec-wrapper"
chmod +x "$t/bin/"*
# run <installer's status>: the script, its status in $rc; its log in $t/home/cachy-install.log
run() {
    rc=0
    (
        export XDG_RUNTIME_DIR=$t/run
        export NOTIFY_WHEN_UP_TRIES=1 DBUS_SESSION_BUS_ADDRESS=unix:path=$t/nobus
        RC=$1 PATH=$t/bin:$PATH HOME=$t/home bash "$script" >"$t/out" 2>&1
    ) || rc=$?
    log=$t/home/cachy-install.log
}

# Gone by itself: said, with its status and its own errors, and the script fails
run 3
((rc == 3)) || fail "the installer's failure not passed on (status $rc): $(cat "$t/out")"
grep -qx 'the installer: calamares -D6' "$log" || fail "the installer not started as before: $(cat "$log")"
grep -qx 'AgrOS: the installer stopped (status 3)' "$log" || fail "its stop not said in the log: $(cat "$log")"
grep -q 'qt.qpa.wayland: something went wrong' "$log" || fail "its errors not in the log: $(cat "$log")"
# Closed as usual: nothing said
run 0
((rc == 0)) && ! grep -q 'installer stopped' "$log" || fail "a usual close said as a stop (status $rc): $(cat "$log")"
echo "ok installer-exit"
