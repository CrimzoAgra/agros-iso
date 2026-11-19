#!/usr/bin/env bash
# .github/cachyos-sync-packages.sh, the CachyOS sync's package check, on a throwaway repo with pacman stubbed (its
# databases a small made-up set, each package a tar of its files): a new package (on the list, or a dependency one
# brings) that starts something by itself is said, with what does it (an autostart entry, a new user's too; a unit
# linked in a .wants/.requires/.upholds folder, a user's too; a preset; a generator; a pacman hook; an install script
# calling systemctl), unless it's allowed with a reason; one already on the ISO isn't; a package AgrOS relies on
# (agros-desktop's dependencies, the installer's optional ones and KPMcore's) gone from the ISO is said, not one
# something else on it still brings, one agros-trim.sh leaves out anyway, or another package's optional one; a name no
# repo has is said; the list unchanged looks nothing up; a repo or download that fails fails the check, never read as
# nothing found
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
unset GITHUB_OUTPUT
list=archiso/packages_desktop.x86_64
# (the check as in main's checkout, beside an allowlist of the test's own: the repo's isn't touched)
mkdir -p "$t/self/.github" "$t/bin" "$t/pkgs"
cp "$here/.github/cachyos-sync-packages.sh" "$t/self/.github/"
cp "$here/.github/cachyos-sync-allowed" "$t/self/.github/"
cp "$here/agros-trim.sh" "$here/util-msg.sh" "$t/self/"
allowed=$t/self/.github/cachyos-sync-allowed

# The repos: "<repo> <name> <depends> <optional depends> <provides>" a line, comma-separated, - for none
cat >"$t/repo" <<'EOF'
core glibc - - -
core base glibc - -
agros cachyos-calamares kpmcore,glibc - calamares
extra kpmcore glibc ntfsprogs:NTFS_support,xfsprogs>=1:XFS -
extra networkmanager glibc iwd:Wi-Fi -
extra iwd - - -
extra ntfsprogs - - -
extra xfsprogs - - -
extra wireplumber pipewire - -
extra pipewire - - -
extra micro - - -
extra steam - - -
agros agros-desktop networkmanager,micro,wireplumber,steam - -
cachyos oldstarter - - -
extra tree libtree - -
extra libtree - - -
cachyos starter - - -
extra bringer starter - -
EOF
# pacman: -Sy; -Sp (a target's dependencies, depth first, unless --nodeps; "error: target not found" for each name no
# repo has, then a failure; a provider's choice said on stdout too, as pacman does); -Si (Optional Deps as pacman lays
# them out). FAIL_PACMAN=1: a repo unreachable, its database not fetched (-Sy fails). Its calls in $t/pacman.log
cat >"$t/bin/pacman" <<'EOF'
#!/usr/bin/env bash
db=$T/repo
echo "$*" >>"$T/pacman.log"
op= fmt= nodeps=0 args=()
while (($#)); do
    case $1 in
        --config | --dbpath) shift 2 ;;
        --print-format) fmt=$2; shift 2 ;;
        --nodeps) nodeps=1; shift ;;
        --noconfirm) shift ;;
        -Sy | -Sp | -Si) op=$1; shift ;;
        *) args+=("$1"); shift ;;
    esac
done
# find <target>: "<repo> <name>" of the package it names (by name or by what it provides; repo/ narrows it)
find() {
    local r= n=$1
    [[ $1 != */* ]] || { r=${1%%/*} n=${1#*/}; }
    awk -v r="$r" -v n="$n" '(r == "" || $1 == r) && ($2 == n || index("," $5 ",", "," n ",")) { print $1, $2; exit }' \
        "$db"
}
field() { awk -v n="$1" -v f="$2" '$2 == n { print $f }' "$db"; }
declare -A seen
out=()
visit() {
    local rn d
    rn=$(find "$1")
    [[ -n $rn ]] || { missing+=("$1"); return; }
    [[ -z ${seen[${rn#* }]:-} ]] || return 0
    seen[${rn#* }]=1
    if ((!nodeps)); then
        for d in $(field "${rn#* }" 3 | tr ',' ' '); do [[ $d == - ]] || visit "$d"; done
    fi
    out+=("${rn% *}/${rn#* }")
}
case $op in
    -Sy) [[ -z ${FAIL_PACMAN:-} ]] || { echo "error: failed retrieving file 'core.db' from mirror" >&2; exit 1; } ;;
    -Sp)
        missing=()
        for a in "${args[@]}"; do visit "$a"; done
        if ((${#missing[@]})); then
            printf 'error: target not found: %s\n' "${missing[@]}" >&2
            exit 1
        fi
        ((nodeps)) || echo ":: There are 2 providers available for jack:"
        for p in "${out[@]}"; do
            if [[ $fmt == *%l* ]]; then echo "$p file://$T/pkgs/${p#*/}.tar"; else echo "$p"; fi
        done
        ;;
    -Si)
        for a in "${args[@]}"; do
            rn=$(find "$a")
            echo "Repository      : ${rn% *}"
            echo "Name            : ${rn#* }"
            o=$(field "${rn#* }" 4)
            if [[ $o == - ]]; then
                echo "Optional Deps   : None"
            else
                tr ',' '\n' <<<"$o" | sed 's/:/: /; s/_/ /g; 1s/^/Optional Deps   : /; 2,$s/^/                  /'
            fi
            echo "Conflicts With  : None"
            echo
        done
        ;;
esac
EOF
chmod +x "$t/bin/pacman"
# (bsdtar, as the Arch container has it; plain tar reads the test's packages the same way where it isn't installed)
command -v bsdtar >/dev/null || printf '#!/bin/sh\nexec tar "$@"\n' >"$t/bin/bsdtar"
chmod +x "$t/bin/"*
export PATH=$t/bin:$PATH T=$t

# pkg <name> [<file>...]: its package, those files in it (".INSTALL=<text>": its install script)
pkg() {
    local d=$t/p/$1 f
    rm -rf "$d" && mkdir -p "$d"
    echo "pkgname = $1" >"$d/.PKGINFO"
    for f in "${@:2}"; do
        if [[ $f == .INSTALL=* ]]; then
            echo "${f#.INSTALL=}" >"$d/.INSTALL"
        else
            mkdir -p "$d/$(dirname "$f")" && echo x >"$d/$f"
        fi
    done
    # (its files at the top, no ./ before them, as a package's)
    (cd "$d" && shopt -s dotglob && tar -cf "$t/pkgs/$1.tar" -- *)
}
for p in $(awk '{ print $2 }' "$t/repo"); do pkg "$p"; done
pkg oldstarter etc/xdg/autostart/oldstarter.desktop

# AgrOS's ISO list: the installer, NetworkManager, the file system tools, PipeWire (a dependency of WirePlumber too), an
# editor agros-trim.sh leaves out, a package that starts something already on it
main='base agros/calamares networkmanager iwd ntfsprogs xfsprogs wireplumber pipewire micro oldstarter'
# case_ <sed for CachyOS's change to the list>: main's commit, the merge after it; the check run on the merge. Its
# status in $rc, its output in $out
case_() {
    rm -rf "$t/r" "$t/pacman.log"
    git init -q -b main "$t/r"
    mkdir -p "$t/r/archiso"
    tr ' ' '\n' <<<"$main" >"$t/r/$list"
    git -C "$t/r" add -A && git -C "$t/r" commit -qm main
    sed -i "$1" "$t/r/$list"
    echo "# their notes" >"$t/r/README.md"
    git -C "$t/r" add -A && git -C "$t/r" commit -qm merge
    rc=0
    out=$(cd "$t/r" && bash "$t/self/.github/cachyos-sync-packages.sh" HEAD 2>&1) || rc=$?
}
why() { sed -n 's/^why=//p' <<<"$out"; }
starts="it adds packages that start things by themselves (.github/cachyos-sync-allowed, with why, if that's fine)"

# The list unchanged (only their docs): nothing looked up
case_ ''
((rc == 0)) && [[ $(why) == "" ]] && grep -qx 'why=' <<<"$out" || fail "the list unchanged: $out"
[[ ! -e $t/pacman.log ]] || fail "the list unchanged, pacman still called: $(cat "$t/pacman.log")"

# A new package (and its dependency) that starts nothing, oldstarter already on the ISO: nothing said
case_ '$a tree'
((rc == 0)) && grep -qx 'why=' <<<"$out" || fail "a harmless package added: $out"
grep -q -- '-Sp' "$t/pacman.log" || fail "a package added, nothing looked up"

# Each way of starting something by itself: said, with the file
for f in etc/xdg/autostart/s.desktop etc/skel/.config/autostart/s.desktop \
    usr/lib/systemd/system/multi-user.target.wants/s.service etc/systemd/system/sockets.target.wants/s.socket \
    usr/lib/systemd/user/default.target.wants/s.service usr/lib/systemd/system/graphical.target.requires/s.service \
    usr/lib/systemd/system/x.target.upholds/s.service etc/skel/.config/systemd/user/default.target.wants/s.service \
    usr/lib/systemd/system-preset/90-s.preset usr/lib/systemd/user-preset/90-s.preset \
    usr/lib/systemd/system-generators/s-generator usr/lib/systemd/user-generators/s \
    usr/share/libalpm/hooks/90-s.hook etc/pacman.d/hooks/s.hook; do
    pkg starter usr/bin/starter usr/lib/systemd/system/s.service "$f"
    case_ '$a starter'
    ((rc == 0)) && [[ $(why) == "$starts: starter ($f)" ]] || fail "a new package with $f: $out"
done
# Its install script calling systemctl (cachyos-settings' enables services): said; one that doesn't, not
pkg starter usr/bin/starter '.INSTALL=post_install() { systemctl enable s.service; }'
case_ '$a starter'
[[ $(why) == "$starts: starter (its install script runs systemctl)" ]] || fail "an install script enabling a unit: $out"
pkg starter usr/bin/starter usr/lib/systemd/system/s.service '.INSTALL=post_install() { echo hi; }'
case_ '$a starter'
grep -qx 'why=' <<<"$out" || fail "a package with a unit it doesn't enable, held: $out"

# Brought in as a dependency of the package their list adds: said too
pkg starter usr/bin/starter etc/xdg/autostart/s.desktop
case_ '$a bringer'
[[ $(why) == "$starts: starter (etc/xdg/autostart/s.desktop)" ]] || fail "a dependency that autostarts: $out"

# Allowed, with a reason: not said. With none, or commented out: said
echo 'starter: AgrOS wants it at login (test)' >"$allowed"
case_ '$a bringer'
grep -qx 'why=' <<<"$out" || fail "an allowed package still said: $out"
for line in 'starter:' 'starter:   ' '# starter: commented out'; do
    echo "$line" >"$allowed"
    case_ '$a bringer'
    [[ $(why) == "$starts: starter"* ]] || fail "allowed by \"$line\": $out"
done
: >"$allowed"

# Gone from the ISO: what agros-desktop needs (NetworkManager), KPMcore's optional file system tools (each said once);
# not WirePlumber's PipeWire (still brought by it), the editor agros-trim.sh leaves out, NetworkManager's optional iwd
case_ '/^networkmanager$/d; /^ntfsprogs$/d; /^xfsprogs$/d; /^pipewire$/d; /^micro$/d; /^iwd$/d'
((rc == 0)) && [[ $(why) == "it takes packages AgrOS relies on off the ISO: networkmanager ntfsprogs xfsprogs" ]] ||
    fail "packages AgrOS relies on gone: $out"
case_ '/^pipewire$/d; /^micro$/d; /^iwd$/d'
grep -qx 'why=' <<<"$out" || fail "packages nothing needs gone, or still brought: $out"

# A name no repo has: said; with what else it finds, after it
case_ '$a nosuch'
[[ $(why) == "it adds packages no repo has: nosuch" ]] || fail "an unknown package: $out"
case_ '$a nosuch
/^ntfsprogs$/d'
[[ $(why) == "it adds packages no repo has: nosuch; it takes packages AgrOS relies on off the ISO: ntfsprogs" ]] ||
    fail "an unknown package, and one gone: $out"

# Can't tell: a repo unreachable, a package that can't be downloaded. A failure, no why= (never "nothing found")
FAIL_PACMAN=1 case_ '$a tree'
((rc != 0)) && ! grep -q '^why=' <<<"$out" || fail "a repo unreachable: rc $rc, $out"
rm "$t/pkgs/tree.tar"
case_ '$a tree'
((rc != 0)) && ! grep -q '^why=' <<<"$out" || fail "a download failing: rc $rc, $out"

# The repo's own allowlist: each line a package and a reason, or a comment
bad=$(tr -d '\r' <"$here/.github/cachyos-sync-allowed" |
    grep -vE '^(#.*|[^#:[:space:]]+:[[:space:]]*[^[:space:]].*|)$' || true)
[[ -z $bad ]] || fail ".github/cachyos-sync-allowed has lines with no reason: $bad"
echo "ok cachyos-sync-packages"
