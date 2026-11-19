#!/usr/bin/env bash
# calamares-online.sh's keyboard follower, on a file of the test's with hyprctl stubbed: the layout the installer's
# keyboard page sets through locale1 (its X11 file) applied to the live session's Hyprland as it changes (not on the US
# layout the session started with, where the users page's password was typed), a variant and options too, gone when
# the new layout has none; the same file again applies nothing; a value that isn't XKB's (a quote, a space, a
# backslash: Lua code) never reaches Hyprland; none at all, nothing; it stops once the script that started it has ended;
# and the script starts it beside the installer
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
script=$here/archiso/airootfs/usr/local/bin/calamares-online.sh
# (the follower as the script has it: its file's line through the function's end, the file then the test's)
tr -d '\r' <"$script" | awk '/^kb_conf=/ { on = 1 } on { print } on && /^}$/ { exit }' >"$t/follow.sh"
grep -q '^follow_keyboard() {$' "$t/follow.sh" || fail "no follow_keyboard in calamares-online.sh"
mkdir "$t/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$T/hyprctl.log"\n' >"$t/bin/hyprctl"
chmod +x "$t/bin/hyprctl"
# (the script that starts it: running until the test makes $t/done, or its folder is gone, a failed test)
cat >"$t/starter.sh" <<'EOF'
. "$T/follow.sh"
kb_conf=$T/kb.conf
follow_keyboard &
echo $! >"$T/pid"
until [ -e "$T/done" ] || [ ! -d "$T" ]; do sleep 0.1; done
EOF
T=$t PATH=$t/bin:$PATH bash "$t/starter.sh" &
starter=$!
# conf <layout> [<variant> [<options>]]: the file as localed writes it
conf() {
    {
        echo 'Section "InputClass"'
        echo '        Identifier "system-keyboard"'
        echo "        Option \"XkbLayout\" \"$1\""
        echo '        Option "XkbModel" "pc105"'
        [[ -z ${2:-} ]] || echo "        Option \"XkbVariant\" \"$2\""
        [[ -z ${3:-} ]] || echo "        Option \"XkbOptions\" \"$3\""
        echo 'EndSection'
    } >"$t/kb.conf.new" && mv "$t/kb.conf.new" "$t/kb.conf"
}
# applied <n>: the hyprctl log has <n> lines, waited for up to 3 s; its last line printed
applied() {
    for _ in {1..30}; do
        [[ $(cat "$t/hyprctl.log" 2>/dev/null | wc -l) -ge $1 ]] && break
        sleep 0.1
    done
    [[ $(cat "$t/hyprctl.log" 2>/dev/null | wc -l) == "$1" ]] || return 1
    tail -n1 "$t/hyprctl.log"
}
eval_of() { echo "eval hl.config({ input = { kb_layout = \"$1\", kb_variant = \"$2\", kb_options = \"$3\" } })"; }

# No file yet: nothing
sleep 1.5
[[ ! -e $t/hyprctl.log ]] || fail "applied with no layout set: $(cat "$t/hyprctl.log")"
# A layout picked: applied
conf pt
[[ $(applied 1) == "$(eval_of pt "" "")" ]] || fail "Portuguese not applied: $(cat "$t/hyprctl.log" 2>/dev/null)"
# Another, with a variant and a second layout's switch key (as the installer sets a non-Latin one)
conf us,ru ,phonetic grp:alt_shift_toggle
[[ $(applied 2) == "$(eval_of us,ru ,phonetic grp:alt_shift_toggle)" ]] ||
    fail "a layout with its variant and options not applied: $(cat "$t/hyprctl.log")"
# Back to one with none: the variant and options cleared, not left from the one before
conf fr
[[ $(applied 3) == "$(eval_of fr "" "")" ]] || fail "the variant and options not cleared: $(cat "$t/hyprctl.log")"
# The same file written again: nothing more
conf fr
sleep 1.5
applied 3 >/dev/null || fail "the same layout applied again: $(cat "$t/hyprctl.log")"
# Not XKB's characters (what could end Lua's string or add to it): never passed on
for bad in 'fr\' 'fr })os.execute(x)--' "fr' '"; do
    conf "$bad"
    sleep 1.5
    applied 3 >/dev/null || fail "\"$bad\" passed to Hyprland: $(cat "$t/hyprctl.log")"
done
# The script that started it ended: it stops
touch "$t/done"
wait "$starter"
pid=$(cat "$t/pid")
for _ in {1..30}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
! kill -0 "$pid" 2>/dev/null || { kill "$pid"; fail "still running after its script ended"; }
# Started beside the installer, in the background, before it opens
awk '/^    follow_keyboard .*&$/ { f = NR } /^    pkexec-wrapper calamares / { p = NR }
    END { exit !(f && p && f < p) }' <(tr -d '\r' <"$script") ||
    fail "calamares-online.sh doesn't start follow_keyboard in the background before the installer"
echo "ok installer-keyboard"
