#!/usr/bin/env bash
# live-session-menu: the live user's Super menu cut down, and no idle timeout but the screen going off (the installed
# system's suspend put the computer to sleep halfway through an install no one touched). On AgrOS's own idle list, on
# none (Caelestia's defaults, a lock and a suspend, would come back without the key) and on no file at all, twice over.
# And the live system's sleep drop-in, refusing a suspend whoever asks
source "$(dirname "$0")/lib.sh"
command -v jq >/dev/null || fail "no jq to run json-edit's filter with"
# (json-edit's job, the file's lock aside: made when missing, changed by the jq filter)
mkdir -p "$t/bin" "$t/home"
printf '%s\n' '#!/bin/sh' 'f=$1; shift' "[ -e \"\$f\" ] || echo '{}' >\"\$f\"" \
    'jq "$@" "$f" >"$f.new" && mv "$f.new" "$f"' >"$t/bin/json-edit"
sed "s|/usr/lib/agros/bin/json-edit|$t/bin/json-edit|" "$here/archiso/airootfs/usr/local/bin/live-session-menu" \
    >"$t/menu"
grep -q "$t/bin/json-edit" "$t/menu" || fail "live-session-menu no longer runs /usr/lib/agros/bin/json-edit"
chmod +x "$t/bin/json-edit"
f=$t/home/.config/caelestia/shell.json
run() { HOME=$t/home sh "$t/menu" || fail "live-session-menu failed"; }
# (AgrOS's idle list as shell.json has it: the screen off and a suspend, on AC and on battery)
mkdir -p "${f%/*}"
cat >"$f" <<'JSON'
{"general": {"logo": "agros-logo", "idle": {"inhibitWhenAudio": true, "lockBeforeSleep": true, "timeouts": [
  {"enabled": true, "idleAction": "dpms off", "inhibitWhenCharging": false, "returnAction": "dpms on", "timeout": 600},
  {"enabled": true, "idleAction": ["systemctl", "suspend"], "inhibitWhenCharging": false, "timeout": 1800},
  {"enabled": true, "idleAction": "dpms off", "inhibitWhenCharging": true, "returnAction": "dpms on", "timeout": 300},
  {"enabled": true, "idleAction": ["systemctl", "suspend"], "inhibitWhenCharging": true, "timeout": 900},
  {"idleAction": "lock", "timeout": 180}]}}}
JSON
run
run
[[ $(jq -c '[.general.idle.timeouts[] | [.idleAction, .timeout, .inhibitWhenCharging]]' "$f") == \
    '[["dpms off",600,false],["dpms off",300,true]]' ]] || fail "not only the screen-off timeouts left: $(cat "$f")"
[[ $(jq -c '[.general.logo, .general.idle.inhibitWhenAudio, .launcher.favouriteApps]' "$f") == \
    '["agros-logo",true,[]]' ]] ||
    fail "the file's other settings not kept, or the dock's pins left: $(cat "$f")"
jq -e '.launcher.hiddenApps | length == 1 and (.[0] | contains("agros-install"))' "$f" >/dev/null ||
    fail "the Super menu not cut down: $(cat "$f")"
# No timeouts key, or no file: an empty list, not Caelestia's own
echo '{"general": {"idle": {"lockBeforeSleep": true}}}' >"$f"
run
[[ $(jq -c '.general.idle.timeouts' "$f") == '[]' ]] || fail "no timeouts key left without an empty list: $(cat "$f")"
rm -f "$f"
run
[[ $(jq -c '.general.idle.timeouts' "$f") == '[]' ]] || fail "no file left without an empty list: $(cat "$f")"

# The live system's sleep drop-in: every kind of sleep refused
d=$here/archiso/airootfs/etc/systemd/sleep.conf.d/do-not-suspend.conf
[[ -f $d ]] || fail "no sleep drop-in on the live system ($d)"
for k in AllowSuspend AllowHibernation AllowSuspendThenHibernate AllowHybridSleep; do
    grep -qx "$k=no" <(tr -d '\r' <"$d") || fail "$k isn't no in $d"
done
grep -qx '\[Sleep\]' <(tr -d '\r' <"$d") || fail "no [Sleep] section in $d"
echo "ok live-session"
