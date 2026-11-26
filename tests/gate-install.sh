#!/usr/bin/env bash
# agros-gate-install, the installer's upstream gate step, on a throwaway installed system: what it decides. The newest
# Hyprland the install downloaded kept when it's approved; not approved, the ISO's own copy installed over it when that
# one is (only the gated packages the new system has, the rest not added), else the newest kept; with the list
# unreachable, the copy installed only when the newest isn't the ISO's own version (a rebuild of it, -1.1, the same),
# and never a test build's copy (ungated); a gated package installed that the copy hasn't, not approved, said; pacman
# failing for part of the set said as it is. A key of the test's own as AgrOS's; curl and pacman stand-ins (pacman's
# local database a file of "name version" lines)
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GNUPGHOME=$t/gnupg
mkdir -m700 "$GNUPGHOME" "$t/bin"
gpg --batch --quiet --passphrase '' --quick-gen-key "agros <agros@agros.invalid>" ed25519 sign never >/dev/null 2>&1
gpg --batch --export agros@agros.invalid >"$t/agros.gpg" 2>/dev/null
export AGROS_GATE_KEYRING=$t/agros.gpg AGROS_GATE_COPY=$t/copy CALLS=$t/calls INSTALLED=$t/root/installed
printf '#!/bin/sh\necho https://agros.invalid/x86_64\n' >"$t/bin/pacman-conf"
# curl: the list ($APPROVED, one "name version" a line) signed by AgrOS's key; $DOWN: unreachable
cat >"$t/bin/curl" <<'C'
#!/bin/bash
[[ -z ${DOWN:-} ]] || exit 7
url=${*: -1}
url=${url%%\?*}
out=/dev/stdout
while (($#)); do [[ $1 == -o ]] && out=$2; shift; done
if [[ $url == *.sig ]]; then
    printf '%s\n' "$APPROVED" | gpg --batch --yes -u agros@agros.invalid --detach-sign -o "$out" 2>/dev/null
else
    printf '%s\n' "$APPROVED" >"$out"
fi
C
# pacman: -Qp a package file (its name and version from the file name), -Q the installed system's version, --sysroot
# <root> -U the files given (from inside it), each installed unless it's named in $UFAIL (all of them refused then)
cat >"$t/bin/pacman" <<'P'
#!/bin/bash
nv() { local f=${1##*/}; f=${f%-x86_64.pkg.tar.zst}; local n=${f%-*-*}; echo "$n ${f#"$n"-}"; }
case $1 in
    -Qp) nv "$2" ;;
    -Q) awk -v n="${*: -1}" '$1 == n { print; f = 1 } END { exit !f }' "$INSTALLED" ;;
    --sysroot)
        echo "-U ${*:6}" >>"$CALLS"
        for f in "${@:6}"; do
            [[ -f $2$f ]] || { echo "error: $f not in the new system"; exit 1; }
            read -r n v < <(nv "$f")
            [[ " ${UFAIL:-} " != *" $n "* ]] || { echo "error: $n can't be installed"; exit 1; }
        done
        for f in "${@:6}"; do
            read -r n v < <(nv "$f")
            awk -v n="$n" -v v="$v" '$1 == n { $2 = v } { print }' "$INSTALLED" >"$INSTALLED.new" && mv "$INSTALLED.new" "$INSTALLED"
        done ;;
    *) exit 2 ;;
esac
P
chmod +x "$t/bin/"*
export PATH=$t/bin:$PATH
# setup <installed...> -- <the copy's...>: a new system with those packages ("name version"), the ISO's copy of those
setup() {
    rm -rf "$t/root" "$t/copy" "$CALLS"
    mkdir -p "$t/root/var/lib/pacman/local" "$t/copy"
    : >"$INSTALLED"
    while (($#)) && [[ $1 != -- ]]; do echo "$1" >>"$INSTALLED"; shift; done
    shift
    for p in "$@"; do : >"$t/copy/${p% *}-${p#* }-x86_64.pkg.tar.zst"; done
}
run() { out=$("$here/archiso/airootfs/usr/local/bin/agros-gate-install" "$t/root" 2>&1) || fail "it failed: $out"; }
has() { [[ $(awk -v n="$1" '$1 == n { print $2 }' "$INSTALLED") == "$2" ]] || fail "$3: $1 is $(grep "^$1 " "$INSTALLED")"; }
untouched() { [[ ! -e $CALLS ]] || fail "$1: pacman installed $(cat "$CALLS")"; }

# The newest not approved, the ISO's approved: the copy installed over it, the gated packages the new system has alone
# (hyprcursor, not installed, not added), from inside the new system, the copy then gone from it; said in its own log
export APPROVED=$'hyprland 0.57.2\nhyprutils 0.10.0'
setup 'hyprland 0.58.0-1' 'hyprutils 0.11.0-1' 'foot 1.0-1' -- 'hyprland 0.57.2-1' 'hyprutils 0.10.0-1' 'hyprcursor 0.1.0-1'
run
[[ $out == *"not approved yet (or the list unreachable): hyprland 0.58.0-1 hyprutils 0.11.0-1; the ISO's own installed instead"* &&
    $out == *"the ISO's Hyprland installed"* ]] || fail "the ISO's approved copy not said as installed: $out"
has hyprland 0.57.2-1 "the copy not installed"
has hyprutils 0.10.0-1 "the copy's library not installed with it"
[[ $(cat "$CALLS") == "-U /var/cache/agros-gate/hyprland-0.57.2-1-x86_64.pkg.tar.zst /var/cache/agros-gate/hyprutils-0.10.0-1-x86_64.pkg.tar.zst" ]] ||
    fail "not the gated packages installed alone, from inside the new system: $(cat "$CALLS")"
[[ ! -e $t/root/var/cache/agros-gate ]] || fail "the copy left in the new system"
grep -q "the ISO's Hyprland installed" "$t/root/var/log/agros-gate-install.log" || fail "not in the new system's log"

# The newest approved: kept
APPROVED=$'hyprland 0.58.0\nhyprutils 0.11.0'
setup 'hyprland 0.58.0-1' 'hyprutils 0.11.0-1' -- 'hyprland 0.57.2-1' 'hyprutils 0.10.0-1'
run
[[ $out == *"Hyprland as installed is approved"* ]] || fail "the approved newest not said: $out"
untouched "the approved newest"
# A rebuild of an approved version (CachyOS's for newer CPUs) is that version
setup 'hyprland 0.58.0-1.1' 'hyprutils 0.11.0-2' -- 'hyprland 0.57.2-1' 'hyprutils 0.10.0-1'
run
untouched "a rebuild of the approved version"

# Neither approved: the newest kept, said, nothing installed
APPROVED='hyprland 0.56.0'
setup 'hyprland 0.58.0-1' -- 'hyprland 0.57.2-1'
run
[[ $out == *"the ISO's own isn't either (hyprland 0.57.2-1): the newest kept"* ]] || fail "neither approved, not said: $out"
untouched "neither approved"

# A gated package installed that the copy hasn't (an ISO from before it was gated), not approved: said
APPROVED=$'hyprland 0.58.0\nhyprwire 0.1.0'
setup 'hyprland 0.58.0-1' 'hyprwire 0.2.0-1' -- 'hyprland 0.57.2-1'
run
[[ $out == *"not approved yet, and not on this ISO to put back: hyprwire 0.2.0-1"* ]] || fail "an unapproved package the copy lacks, not said: $out"
untouched "one the copy lacks"

# The list unreachable: the ISO's own version (a rebuild of it too) kept; another one, the copy installed; a test
# build's copy (ungated) never
export DOWN=1
setup 'hyprland 0.57.2-1.1' 'hyprutils 0.10.0-1' -- 'hyprland 0.57.2-1' 'hyprutils 0.10.0-1'
run
[[ $out == *"Hyprland as installed is the ISO's own (the approved list unreachable)"* ]] || fail "the ISO's own version not said: $out"
untouched "the ISO's own version, the list unreachable"
setup 'hyprland 0.58.0-1' 'hyprutils 0.10.0-1' -- 'hyprland 0.57.2-1' 'hyprutils 0.10.0-1'
run
has hyprland 0.57.2-1 "the list unreachable, the copy not installed over a newer one"
setup 'hyprland 0.58.0-1' -- 'hyprland 0.57.2-1'
: >"$t/copy/ungated"
run
[[ $out == *"this ISO's Hyprland a test build's (not checked): the installed one kept"* ]] || fail "a test build's copy not said: $out"
untouched "a test build's copy"
unset DOWN

# pacman refusing part of the set (a library of the newest that no longer fits): said as it is, nothing half-said
APPROVED='hyprland 0.57.2'
setup 'hyprland 0.58.0-1' -- 'hyprland 0.57.2-1'
UFAIL=hyprland run
[[ $out == *"the ISO's Hyprland couldn't be installed (pacman's reason above): the newest kept"* ]] || fail "pacman's refusal not said: $out"
has hyprland 0.58.0-1 "a refused install"

# No installed system, or no copy on the ISO: nothing done
out=$("$here/archiso/airootfs/usr/local/bin/agros-gate-install" "$t/none" 2>&1) || fail "no system: it failed: $out"
[[ $out == *"gate skipped"* ]] || fail "no system not said: $out"
setup 'hyprland 0.58.0-1' --
run
[[ $out == *"no Hyprland copy on this ISO: gate skipped"* ]] || fail "no copy not said: $out"
echo "ok gate-install"
