#!/usr/bin/env bash
# The ISO built only from a green pipeline: util.sh's gate_current reads the day AgrOS's CI last passed its checks on
# Arch (agros-arch-ok, beside the [agros] repo), taken only with a good signature by AgrOS's key beside it, as the
# approved list; today's lets the build on, one over 28 hours past its start is a wait (gate_waits says it, nothing
# else looked at), and none with a good signature, from every server, or one that isn't a day, stops it. A key of the
# test's own as AgrOS's (agros.asc); curl, pacman-conf and sudo stand-ins. And [agros]'s first server down: the next one's
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GNUPGHOME=$t/gnupg
mkdir -m700 "$GNUPGHOME"
for k in agros other; do
    gpg --batch --quiet --passphrase '' --quick-gen-key "$k <$k@agros.invalid>" ed25519 sign never >/dev/null 2>&1
done
mkdir -p "$t/src/archiso" "$t/bin"
gpg --batch --armor --export agros@agros.invalid >"$t/src/agros.asc" 2>/dev/null
printf '#!/bin/sh\necho "${SERVERS:-https://agros.invalid/x86_64}"\n' >"$t/bin/pacman-conf"
# (sudo: the ISO's packages never looked up here, nor anything run as root)
printf '#!/bin/sh\nexit 1\n' >"$t/bin/sudo"
# curl: agros-arch-ok ($DAY) and agros-approved, past Pages' cache (?t=), each signed by AgrOS's key ($SIG other:
# another key's; none: a 404); down.invalid unreachable
cat >"$t/bin/curl" <<'C'
#!/bin/bash
url=${*: -1}
[[ $url == *'?t='* ]] || exit 22
[[ $url != https://down.invalid/* ]] || exit 7
url=${url%%\?*}
out=/dev/stdout
while (($#)); do [[ $1 == -o ]] && out=$2; shift; done
case ${url##*/} in
    agros-arch-ok*) body=$DAY ;;
    # ($AT: agros-pass-time's Unix time; unset: not published yet, a 404)
    agros-pass-time*) [[ -n ${AT+set} ]] || exit 22; body=$AT ;;
    agros-approved*) body='hyprland 0.58.0' ;;
    *) exit 22 ;;
esac
if [[ $url != *.sig ]]; then printf '%s\n' "$body" >"$out"; exit 0; fi
case ${SIG:-} in
    none) exit 22 ;;
    other) printf '%s\n' "$body" | gpg --batch --yes -u other@agros.invalid --detach-sign -o "$out" 2>/dev/null ;;
    *) printf '%s\n' "$body" | gpg --batch --yes -u agros@agros.invalid --detach-sign -o "$out" 2>/dev/null ;;
esac
C
chmod +x "$t/bin/"*
export PATH=$t/bin:$PATH
src_dir=$t/src
# shellcheck source=../util-msg.sh
. "$here/util-msg.sh"
# shellcheck source=../util.sh
. "$here/util.sh"

export DAY
DAY=$(date -u +%Y/%m/%d)
out=$( (gate_current) 2>&1) || fail "today's day not taken: $out"
[[ -z $out ]] || fail "today's day said as a wait: $out"
DAY=$(date -ud '-29 hours' +%Y/%m/%d)
out=$( (gate_current) 2>&1) || fail "an old day stopped the build, not a wait: $out"
[[ $out == "anything (AgrOS's CI last passed its checks on Arch on $DAY)" ]] || fail "an old day not said as a wait: $out"
# gate_waits: that wait alone, the ISO's packages never looked up (sudo fails here)
out=$( (gate_waits) 2>&1) || fail "gate_waits stopped on an old day: $out"
[[ $out == "anything (AgrOS's CI last passed its checks on Arch on $DAY)" ]] || fail "gate_waits didn't say the old day: $out"
DAY=$(date -u +%Y/%m/%d)
for sig in none other; do
    out=$( (SIG=$sig gate_current) 2>&1) && fail "a day with no good signature ($sig) taken: $out"
    [[ $out == *"AgrOS's CI results on Arch have no good signature by AgrOS's key (https://agros.invalid/x86_64/agros-arch-ok.sig)"* ]] ||
        fail "a day with no good signature ($sig) not said: $out"
done
out=$( (SERVERS=$'https://down.invalid/x86_64\nhttps://agros.invalid/x86_64' gate_current) 2>&1) ||
    fail "the day not taken from the second server: $out"
[[ -z $out ]] || fail "the second server's day said as a wait: $out"
out=$( (SERVERS=https://down.invalid/x86_64 gate_current) 2>&1) && fail "no server reached, taken: $out"
[[ $out == *"couldn't be fetched (https://down.invalid/x86_64/agros-arch-ok)"* ]] || fail "no server reached, not said: $out"
DAY='<html>'
out=$( (gate_current) 2>&1) && fail "a page that isn't a day taken: $out"
[[ $out == *"aren't a day (https://agros.invalid/x86_64/agros-arch-ok)"* ]] || fail "a page that isn't a day not said: $out"
# When CI last passed, to the second (agros-pass-time): within 26 hours the build goes on, yesterday's day or not (the
# nightly run started late); past that, a wait saying when; empty (none yet): the day's rule
export AT
DAY=$(date -ud '-29 hours' +%Y/%m/%d) AT=$(($(date +%s) - 20 * 3600))
out=$( (gate_current) 2>&1) && [[ -z $out ]] || fail "a pass 20 hours ago a wait: $out"
AT=$(($(date +%s) - 27 * 3600))
out=$( (gate_current) 2>&1) || fail "a pass 27 hours ago stopped the build, not a wait: $out"
[[ $out == "anything (AgrOS's CI last passed its checks on Arch at $(date -ud "@$AT" '+%Y/%m/%d %H:%M') UTC)" ]] ||
    fail "a pass 27 hours ago not said as a wait: $out"
AT=''
out=$( (gate_current) 2>&1) && [[ $out == "anything (AgrOS's CI last passed its checks on Arch on $DAY)" ]] ||
    fail "an empty pass time not left to the day's rule: $out"
echo "ok gate-current"
