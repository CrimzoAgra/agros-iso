#!/usr/bin/env bash
# calamares-online.sh's splash, with the desktop's tools stubbed: opened drawn on the CPU (from the session's autostart
# it has no LIBGL_ALWAYS_SOFTWARE, and on VMware's GPU its window was refused: never seen), saying what it waits for,
# and closed when the installer can't be set up. Started again while it gets ready: the splash opened again if the user
# closed it, never two. No XDG_RUNTIME_DIR: no splash, nothing in /tmp
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
script=$here/archiso/airootfs/usr/local/bin/calamares-online.sh
mkdir -p "$t/bin" "$t/run"
# (qs: the splash records its environment and pid, then stays up as the real one does; qs ipc: Caelestia's bar up)
cat >"$t/bin/qs" <<'EOF'
#!/bin/sh
[ "$1" = -p ] || exit 0
echo $$ >"$T/qs.pid"
echo "LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE-}" >"$T/qs.env"
exec sleep 30
EOF
printf '#!/bin/sh\necho full\n' >"$t/bin/nmcli"
printf '#!/bin/sh\necho yes\n' >"$t/bin/timedatectl"
printf '#!/bin/sh\nexit 1\n' >"$t/bin/hyprctl"
# (the keyring step fails: the installer not set up. Once the splash is up, so its close is what's checked)
printf '#!/bin/sh\nfor i in 1 2 3 4 5 6 7 8 9 10; do [ -e "$T/qs.env" ] && break; sleep 0.5; done\nexit 1\n' >"$t/bin/sudo"
chmod +x "$t/bin/"*
# (no session bus: its notification goes nowhere, not to the desktop running the tests)
mkdir "$t/home"
# run [no-runtime-dir]: XDG_RUNTIME_DIR is $t/run, or unset
run() { (
    if [[ ${1-} == no-runtime-dir ]]; then unset XDG_RUNTIME_DIR; else export XDG_RUNTIME_DIR=$t/run; fi
    T=$t PATH=$t/bin:$PATH HOME=$t/home DBUS_SESSION_BUS_ADDRESS=unix:path=$t/nobus bash "$script" >"$t/out" 2>&1
) }

rc=0
run || rc=$?
[[ $rc == 1 ]] || fail "the keyring step failing didn't stop it (status $rc): $(cat "$t/out")"
[[ -s $t/qs.env ]] || fail "no splash opened"
grep -qx 'LIBGL_ALWAYS_SOFTWARE=1' "$t/qs.env" || fail "the splash isn't drawn on the CPU: $(cat "$t/qs.env")"
[[ $(cat "$t/run/agros-installer-splash") == "Getting the installer ready…" ]] ||
    fail "the splash says: $(cat "$t/run/agros-installer-splash")"
pid=$(cat "$t/qs.pid")
for _ in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
! kill -0 "$pid" 2>/dev/null || { kill "$pid"; fail "the splash left open after the installer couldn't be set up"; }

# Started again while the first gets ready (its lock held): it stops. Its splash closed by the user: opened again, for
# the first run to close (its pid recorded); its splash up: no second one
rm -f "$t/qs.env" "$t/qs.pid"
flock "$t/run/.calamares-online.lock" sleep 5 &
sleep 0.5
rc=0
run || rc=$?
[[ $rc == 0 ]] || fail "a second start while it gets ready failed (status $rc): $(cat "$t/out")"
for _ in {1..20}; do [[ -s $t/qs.env ]] && break; sleep 0.1; done
[[ -s $t/qs.env ]] || fail "a second start didn't open again the splash the user closed"
pid=$(cat "$t/qs.pid")
[[ $(cat "$t/run/agros-installer-splash.pid") == "$pid" ]] || fail "the splash opened again isn't the one the first run closes"
rm -f "$t/qs.env"
rc=0
run || rc=$?
sleep 0.5
kill "$pid"
wait
[[ $rc == 0 ]] || fail "a second start with the splash up failed (status $rc): $(cat "$t/out")"
[[ ! -e $t/qs.env ]] || fail "a second start opened a second splash"

# No XDG_RUNTIME_DIR: no splash, and nothing in the shared /tmp (another account could plant or watch a fixed name
# there); its lock in the user's home instead
[[ -e /tmp/agros-installer-splash ]] && planted=1 || planted=0
rc=0
run no-runtime-dir || rc=$?
[[ $rc == 1 ]] || fail "with no XDG_RUNTIME_DIR, the keyring step failing didn't stop it (status $rc): $(cat "$t/out")"
[[ ! -e $t/qs.env ]] || fail "a splash opened with no XDG_RUNTIME_DIR"
((planted)) || [[ ! -e /tmp/agros-installer-splash ]] || fail "the splash's file written in /tmp"
[[ -e $t/home/.calamares-online.lock ]] || fail "with no XDG_RUNTIME_DIR, the lock isn't in the home"
echo "ok installer-splash"
