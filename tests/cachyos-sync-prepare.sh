#!/usr/bin/env bash
# .github/cachyos-sync.sh prepare, on throwaway repos (CachyOS's, and this one's origin) with gh stubbed: a merge that
# keeps what AgrOS changed in the ISO's package list is a candidate (its ISO and tests next); one bringing back a package
# AgrOS left out, adding a KDE one, without AgrOS's installer (agros/calamares), or changing any file but docs, images
# and the package list is a pull request saying why
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
unset GITHUB_OUTPUT
g() { git -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
mkdir "$t/bin"
# (gh: its arguments logged, and a pull request's text kept in $t/body)
cat >"$t/bin/gh" <<SH
#!/bin/sh
echo "\$*" >>"$t/gh.log"
while [ \$# -gt 0 ]; do [ "\$1" != --body-file ] || cat "\$2" >"$t/body"; shift; done
SH
chmod +x "$t/bin/gh"
export PATH=$t/bin:$PATH
list=archiso/packages_desktop.x86_64

# case <sed for AgrOS's list> <sed for CachyOS's next commit> [files their commit adds, or old>new it renames
# (old in the base)...]: CachyOS's list (20 packages, its installer the 12th, a KDE one the 5th) as main's base; main
# with AgrOS's changes; CachyOS's master one commit on; prepare run in a fresh checkout of origin. Its status in $rc, its output in $out
case_() {
    local f
    rm -rf "$t/up" "$t/origin.git" "$t/w" "$t/gh.log"
    g init -q -b master "$t/up"
    mkdir -p "$t/up/archiso"
    seq -f 'pkg%g' 20 | sed 's/^pkg5$/konsole/; s/^pkg12$/cachyos-calamares-staging/' >"$t/up/$list"
    for f in "${@:3}"; do
        [[ $f != *'>'* ]] || { mkdir -p "$(dirname "$t/up/${f%>*}")" && echo x >"$t/up/${f%>*}"; }
    done
    g -C "$t/up" add -A && g -C "$t/up" commit -qm base
    g init -q --bare "$t/origin.git"
    g clone -q "$t/up" "$t/agros"
    sed -i "$1" "$t/agros/$list"
    g -C "$t/agros" commit -qam agros && g -C "$t/agros" push -q "$t/origin.git" HEAD:refs/heads/main
    rm -rf "$t/agros"
    sed -i "$2" "$t/up/$list"
    for f in "${@:3}"; do
        if [[ $f == *'>'* ]]; then
            mkdir -p "$(dirname "$t/up/${f#*>}")" && g -C "$t/up" mv "${f%>*}" "${f#*>}"
        else
            mkdir -p "$(dirname "$t/up/$f")" && echo x >"$t/up/$f"
        fi
    done
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

# A conflict with AgrOS's changes: a pull request naming the file, and saying to merge by hand the branch "cachyos"
# (their master with AgrOS's workflows), never their master itself, whose workflows would come in with it
case_ "$agros"$'\ns/^pkg3$/pkgA/' 's/^pkg3$/pkgB/'
grep -qx "why=it conflicts with AgrOS's changes" <<<"$out" || fail "a conflict not said: $out"
grep -qx -- '- `archiso/packages_desktop.x86_64`' "$t/body" || fail "the conflicting file not in the pull request: $(cat "$t/body")"
grep -qF '`git fetch origin cachyos && git merge origin/cachyos`' "$t/body" && ! grep -q 'FETCH_HEAD\|master' "$t/body" ||
    fail "the pull request doesn't say to merge the branch cachyos by hand, or names their master: $(cat "$t/body")"

# held <file> <why's files>: held for a look, a pull request naming those files
held() {
    grep -qx "why=it changes files to look at first (not only docs, images or the package list): $2" <<<"$out" ||
        fail "a change to $1 not held for a look: $out"
    ! grep -q '^candidate=' <<<"$out" && grep -q '^pr create' "$t/gh.log" || fail "a change to $1 merged by itself: $out"
}
# Any file of theirs but docs, images and the package list: a pull request naming it, whatever else changed. Those
# that run as root or decide what's trusted, the live user's (it has sudo with no password), the boot menus' (the
# kernel's command line), scripts anywhere, and one nobody thought of (motd)
for f in buildiso.sh util-iso.sh archiso/profiledef.sh archiso/pacman.conf \
    archiso/airootfs/etc/sudoers.d/x archiso/airootfs/etc/polkit-1/rules.d/x.rules archiso/airootfs/etc/pacman.d/hooks/x.hook \
    archiso/airootfs/etc/systemd/system/multi-user.target.wants/x.service archiso/airootfs/etc/ssh/sshd_config.d/x.conf \
    archiso/airootfs/etc/shadow archiso/airootfs/root/.zlogin archiso/airootfs/usr/local/bin/x \
    archiso/airootfs/etc/calamares/settings.conf archiso/airootfs/usr/share/calamares/branding/x/branding.desc keys/x.gpg \
    archiso/airootfs/etc/greetd/config.toml archiso/airootfs/etc/udev/rules.d/x.rules archiso/airootfs/etc/pam.d/x \
    archiso/airootfs/etc/tmpfiles.d/x.conf archiso/airootfs/etc/profile.d/x.sh archiso/airootfs/etc/ld.so.preload \
    archiso/airootfs/etc/mkinitcpio.conf.d/x.conf archiso/airootfs/usr/lib/systemd/system/x.service \
    archiso/airootfs/usr/share/polkit-1/rules.d/x.rules archiso/airootfs/etc/skel/.zshrc \
    archiso/airootfs/etc/xdg/autostart/x.desktop archiso/airootfs/home/liveuser/.config/x archiso/airootfs/usr/bin/x \
    archiso/grub/grub.cfg archiso/efiboot/loader/entries/01-archiso-linux.conf archiso/syslinux/archiso_sys-linux.cfg \
    archiso/airootfs/usr/share/x/x.sh archiso/airootfs/etc/motd docs/x/x.md archiso/airootfs/x.md; do
    case_ "$agros" '8a newtool' archiso/syslinux/splash.png "$f"
    held "$f" "$f"
done
# A rename by both its names: a file moved to a harmless name, or a harmless one moved anywhere else, held
case_ "$agros" '8a newtool' 'archiso/airootfs/etc/sudoers.d/x>README2.md'
held "a move out of sudoers.d" archiso/airootfs/etc/sudoers.d/x
case_ "$agros" '8a newtool' 'docs/x.md>archiso/airootfs/usr/bin/x'
held "a move into usr/bin" archiso/airootfs/usr/bin/x
# Docs, images (a boot menu's background, branding) and the package list: a candidate, renamed among them too
case_ "$agros" '8a newtool' archiso/syslinux/splash.png archiso/airootfs/usr/share/agros/x.jpg CHANGELOG.md \
    manual/x.md docs/images/x.png LICENSE .gitignore 'docs/a.md>docs/b.md'
grep -q '^candidate=' <<<"$out" || fail "a change to docs and images held: $out"

# A workflow of theirs, new or changed: never pushed nor merged (main's own in its place: GitHub's token may not push a
# workflow file, and a branch is checked by its whole tree; their master as it is was refused each day). The branch
# "cachyos" their master with main's workflows on top, its own commit; the merge a candidate without theirs
case_ "$agros" '8a newtool' .github/workflows/build.yml
grep -q '^candidate=' <<<"$out" || fail "a workflow of theirs held the merge, or failed it: $out"
c=$(sed -n 's/^candidate=//p' <<<"$out")
! g -C "$t/origin.git" cat-file -e "$c:.github/workflows/build.yml" 2>/dev/null || fail "a workflow of theirs merged"
! g -C "$t/origin.git" cat-file -e cachyos:.github/workflows/build.yml 2>/dev/null || fail "a workflow of theirs pushed"
[[ $(g -C "$t/origin.git" rev-parse cachyos^) == "$(g -C "$t/up" rev-parse HEAD)" ]] ||
    fail "the branch cachyos isn't their master with one commit on it"
grep -qx 'new=1' <<<"$out" || fail "AgrOS's commit on their master counted as one of theirs: $out"
# ...main's own workflows kept in it (its pull request shows none of them as gone)
w=$(mktemp -d) && g clone -q "$t/origin.git" "$w" && mkdir -p "$w/.github/workflows" && echo ours >"$w/.github/workflows/iso.yml" &&
    g -C "$w" add -A && g -C "$w" commit -qm workflows && g -C "$w" push -q origin HEAD:main && rm -rf "$w" "$t/w"
g clone -q "$t/origin.git" "$t/w"
out=$(cd "$t/w" && CACHYOS_URL=$t/up bash "$here/.github/cachyos-sync.sh" prepare 2>&1) || fail "prepare with main's workflows failed: $out"
[[ $(g -C "$t/origin.git" show cachyos:.github/workflows/iso.yml) == ours ]] &&
    ! g -C "$t/origin.git" cat-file -e cachyos:.github/workflows/build.yml 2>/dev/null ||
    fail "the branch cachyos hasn't main's workflows in place of theirs"
# The repo's own list names the installer as the check looks for it
grep -qx 'agros/calamares' <(sed 's/#.*//; s/[[:space:]]//g' "$here/$list") ||
    fail "the ISO's package list has no agros/calamares, which the sync checks for"
echo "ok cachyos-sync-prepare"
