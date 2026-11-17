#!/usr/bin/env bash
# .github/cachyos-sync.sh prepare, on throwaway repos (CachyOS's, and this one's origin) with gh stubbed: a merge that
# keeps what AgrOS changed in the ISO's package list is a candidate (its ISO and tests next); one bringing back a package
# AgrOS left out, adding a KDE one, without AgrOS's installer (agros/calamares), or changing a file that runs as root or
# decides what's trusted is a pull request saying why
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
unset GITHUB_OUTPUT
g() { git -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
mkdir "$t/bin"
printf '#!/bin/sh\necho "$*" >>"%s/gh.log"\n' "$t" >"$t/bin/gh"
chmod +x "$t/bin/gh"
export PATH=$t/bin:$PATH
list=archiso/packages_desktop.x86_64

# case <sed for AgrOS's list> <sed for CachyOS's next commit> [files their commit adds...]: CachyOS's list (20
# packages, its installer the 12th, a KDE one the 5th) as main's base; main with AgrOS's changes; CachyOS's master one
# commit on; prepare run in a fresh checkout of origin. Its status in $rc, its output in $out
case_() {
    local f
    rm -rf "$t/up" "$t/origin.git" "$t/w" "$t/gh.log"
    g init -q -b master "$t/up"
    mkdir -p "$t/up/archiso"
    seq -f 'pkg%g' 20 | sed 's/^pkg5$/konsole/; s/^pkg12$/cachyos-calamares-staging/' >"$t/up/$list"
    g -C "$t/up" add -A && g -C "$t/up" commit -qm base
    g init -q --bare "$t/origin.git"
    g clone -q "$t/up" "$t/agros"
    sed -i "$1" "$t/agros/$list"
    g -C "$t/agros" commit -qam agros && g -C "$t/agros" push -q "$t/origin.git" HEAD:refs/heads/main
    rm -rf "$t/agros"
    sed -i "$2" "$t/up/$list"
    for f in "${@:3}"; do mkdir -p "$(dirname "$t/up/$f")" && echo x >"$t/up/$f"; done
    g -C "$t/up" add -A && g -C "$t/up" commit -qm theirs
    g clone -q "$t/origin.git" "$t/w"
    rc=0
    out=$(cd "$t/w" && CACHYOS_URL=$t/up bash "$here/.github/cachyos-sync.sh" prepare 2>&1) || rc=$?
}
# AgrOS's own changes: KDE's package left out, its installer in place of CachyOS's, its desktop added
agros='/^konsole$/d; s/^cachyos-calamares-staging$/agros\/calamares/; $a hyprland'

# A package of CachyOS's own added: a candidate, no pull request
case_ "$agros" '8a newtool'
((rc == 0)) || fail "a clean merge failed: $out"
grep -q '^candidate=[0-9a-f]\{40\}$' <<<"$out" || fail "a clean merge not a candidate: $out"
! grep -q '^why=' <<<"$out" || fail "a clean merge said why not: $out"
[[ ! -e $t/gh.log ]] || fail "a clean merge opened a pull request: $(cat "$t/gh.log")"

# A package AgrOS left out, back in their list: a pull request, said why
case_ "$agros" '17a konsole'
grep -qx "why=it would bring back packages AgrOS left out: konsole" <<<"$out" || fail "konsole back not said: $out"
! grep -q '^candidate=' <<<"$out" || fail "konsole back a candidate: $out"
grep -q '^pr create' "$t/gh.log" || fail "konsole back: no pull request"

# A KDE package added: a pull request
case_ "$agros" '8a plasma-workspace'
grep -qx "why=it would add KDE packages: plasma-workspace" <<<"$out" || fail "a KDE package not said: $out"

# AgrOS's installer gone from the list: a pull request
case_ '/^konsole$/d; /^cachyos-calamares-staging$/d; $a hyprland' '8a newtool'
grep -qx "why=AgrOS's own installer (agros/calamares) would leave the package list" <<<"$out" ||
    fail "the installer gone not said: $out"

# A file of theirs that runs as root or decides what's trusted: a pull request naming it, whatever else changed; other
# files (a boot menu's background, a file in the live user's home): a candidate
for f in buildiso.sh util-iso.sh .github/workflows/x.yml archiso/profiledef.sh archiso/pacman.conf \
    archiso/airootfs/etc/sudoers.d/x archiso/airootfs/etc/polkit-1/rules.d/x.rules archiso/airootfs/etc/pacman.d/hooks/x.hook \
    archiso/airootfs/etc/systemd/system/multi-user.target.wants/x.service archiso/airootfs/etc/ssh/sshd_config.d/x.conf \
    archiso/airootfs/etc/shadow archiso/airootfs/root/.zlogin archiso/airootfs/usr/local/bin/x \
    archiso/airootfs/etc/calamares/settings.conf archiso/airootfs/usr/share/calamares/branding/x/branding.desc keys/x.gpg; do
    case_ "$agros" '8a newtool' archiso/syslinux/splash.png "$f"
    grep -qx "why=it changes files to look at first (they run as root or decide what's trusted): $f" <<<"$out" ||
        fail "a change to $f not held for a look: $out"
    ! grep -q '^candidate=' <<<"$out" && grep -q '^pr create' "$t/gh.log" || fail "a change to $f merged by itself: $out"
done
case_ "$agros" '8a newtool' archiso/syslinux/splash.png archiso/airootfs/home/liveuser/.config/x archiso/airootfs/etc/motd
grep -q '^candidate=' <<<"$out" || fail "a change to files of no concern held: $out"

# The repo's own list names the installer as the check looks for it
grep -qx 'agros/calamares' <(sed 's/#.*//; s/[[:space:]]//g' "$here/$list") ||
    fail "the ISO's package list has no agros/calamares, which the sync checks for"
echo "ok cachyos-sync-prepare"
