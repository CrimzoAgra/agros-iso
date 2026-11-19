#!/usr/bin/env bash
# The CachyOS sync's package check (cachyos-sync.yml's packages job, before the merge's ISO is built; in an Arch
# container: pacman, bsdtar, git): what a merge of CachyOS's changes does to the live ISO's packages, worked out from
# the package databases as the ISO's pacman would resolve its list (agros-trim.sh run on a copy first, as the build
# does; nothing installed, as agros's weekly size watch, ci/sizes.sh there). Two things a merge mustn't do by itself,
# however harmless the list's change looks:
# - add a package (one of the list's, or a dependency one brings) that starts something by itself: an autostart entry
#   (etc/xdg/autostart, or a new user's own in etc/skel, as cachyos-hello's: at every login, live and installed), a
#   systemd unit it enables with its files (a link in a .wants, .requires or .upholds folder), a preset or a generator
#   (they enable units too), a pacman hook (run as root at each install or upgrade), or an install script that calls
#   systemctl (cachyos-settings' enables three services). Read from the package itself, downloaded and listed, its
#   .INSTALL read: never installed or run. Unless it's in .github/cachyos-sync-allowed, with why that's fine
# - take off the ISO (nothing on its list brings it any more) a package AgrOS relies on: one agros-desktop needs, every
#   level of its dependencies as [agros] publishes it (what AgrOS's desktop, the live session's too, runs on: Network
#   Manager, PipeWire...; the installer's own, with agros/calamares), or one the installer may run: the optional
#   dependencies of agros/calamares and of KPMcore, its partitioning (each file system's tools, ntfsprogs to shrink
#   Windows' partition). Not every level's optional ones: NetworkManager's alone (iwd, dnsmasq...) would hold back
#   CachyOS's dropping a rescue tool AgrOS never runs
#   .github/cachyos-sync-packages.sh <merge commit>      (its first parent: main, as prepare merged onto it)
# Writes why=<what it found> to $GITHUB_OUTPUT (or stdout), empty when there's nothing; the workflow then builds the
# ISO, or makes the pull request saying why. Can't tell (a repo unreachable, a list pacman can't resolve): fails, no
# why=, and the pull request says the check failed; the next day's run tries again
set -euo pipefail
export LC_ALL=C
commit=${1:?usage: cachyos-sync-packages.sh <merge commit>}
out=${GITHUB_OUTPUT:-/dev/stdout}
here=$(cd "$(dirname "$0")/.." && pwd)
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT

# trimmed <commit> <name>: that commit's ISO package list in $w/<name>.list, as the build leaves it (agros-trim.sh,
# this checkout's, on a copy of the commit's profile)
trimmed() {
    mkdir "$w/$2"
    git archive "$1" archiso | tar -x -C "$w/$2"
    cp "$w/$2/archiso/packages_desktop.x86_64" "$w/$2/archiso/packages.x86_64"
    bash "$here/agros-trim.sh" "$w/$2/archiso" >"$w/$2.trim" 2>&1 || { cat "$w/$2.trim" >&2; return 1; }
    sed 's/#.*//; s/[[:space:]]//g; /^$/d' "$w/$2/archiso/packages.x86_64" | sort -u >"$w/$2.list"
}
trimmed "$commit^1" main
trimmed "$commit" merge
# (the list unchanged, which most of their commits leave it: nothing to look up)
if cmp -s "$w/main.list" "$w/merge.list"; then
    echo "why=" >>"$out"
    exit 0
fi

# (its own pacman config and database, the container's untouched; no signatures checked: only the databases are read
# and packages listed, nothing installed. The repos the ISO's archiso/pacman.conf has, CachyOS's x86_64 one first)
cat >"$w/pacman.conf" <<'EOF'
[options]
Architecture = x86_64
SigLevel = Never
[cachyos]
Server = https://mirror.cachyos.org/repo/$arch/$repo
Server = https://cdn77.cachyos.org/repo/$arch/$repo
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[multilib]
Include = /etc/pacman.d/mirrorlist
[agros]
Server = https://crimzoagra.github.io/agros/$arch
Server = https://pub-f1a3a482900748e8b69cd81361ab96e1.r2.dev/repo/$arch
EOF
mkdir "$w/db"
pac() { pacman --config "$w/pacman.conf" --dbpath "$w/db" "$@"; }
pac -Sy >/dev/null
# resolve <names file> <out>: every package those names install, dependencies too ("<repo>/<name> <its download>"
# each, pacman's default for a virtual one, as the build's --noconfirm). Names no repo has (their whole -Sp stops, each
# said): in <out>.unknown, the rest resolved without them. Anything else pacman stops on fails
resolve() {
    local names
    mapfile -t names <"$1"
    : >"$2.unknown"
    if ! pac -Sp --noconfirm --print-format '%r/%n %l' "${names[@]}" >"$2" 2>"$w/err"; then
        sed -n 's/^error: target not found: //p' "$w/err" | sort -u >"$2.unknown"
        [[ -s $2.unknown ]] || { cat "$w/err" >&2; return 1; }
        mapfile -t names < <(grep -vxFf "$2.unknown" "$1")
        pac -Sp --noconfirm --print-format '%r/%n %l' "${names[@]}" >"$2" 2>"$w/err" || { cat "$w/err" >&2; return 1; }
    fi
    # (only the packages: a provider's choice is said on the same output)
    grep -E '^[^ /]+/[^ /]+ [a-z]+://' "$2" | sort -u -o "$2"
}
names() { sed 's/ .*//; s/^[^/]*\///' "$1" | sort -u; }
resolve "$w/main.list" "$w/main.pkgs"
resolve "$w/merge.list" "$w/merge.pkgs"
held=()

# (a name of theirs no repo has: its packages can't be read. The ISO wouldn't build either)
unknown=$(comm -13 "$w/main.pkgs.unknown" "$w/merge.pkgs.unknown" | paste -sd' ')
[[ -z $unknown ]] || held+=("it adds packages no repo has: $unknown")

# What starts by itself: an autostart entry anywhere (etc/xdg, a new user's in etc/skel), a unit linked in a .wants,
# .requires or .upholds folder (system or user, a new user's too), a preset or a generator, a pacman hook
starts=(
    '(^|/)autostart/[^/]+\.desktop$'
    '(^|/)systemd/(system|user)/[^/]+\.(wants|requires|upholds)/[^/]+$'
    '(^|/)systemd/[^/]+-(preset|generators)/[^/]+$'
    '^(usr/share/libalpm|etc/pacman\.d)/hooks/[^/]+\.hook$'
)
starts_re=$(IFS="|" && echo "${starts[*]}")
# (allowed: "<name>: <why it's fine>" lines; one with no reason doesn't count)
allowed=$(sed -n 's/^\([^#:[:space:]][^:[:space:]]*\):[[:space:]]*[^[:space:]].*/\1/p' "$here/.github/cachyos-sync-allowed")
found=()
while read -r pkg url; do
    name=${pkg#*/}
    ! grep -qxF "$name" <<<"$allowed" || continue
    curl -fsSL --retry 3 --retry-all-errors -o "$w/pkg" "$url"
    files=$(bsdtar -tf "$w/pkg")
    hits=$(grep -E "$starts_re" <<<"$files" | paste -sd' ' || true)
    if grep -qx '\.INSTALL' <<<"$files" && bsdtar -xOf "$w/pkg" .INSTALL | grep systemctl >/dev/null; then
        hits="${hits:+$hits }its install script runs systemctl"
    fi
    [[ -z $hits ]] || found+=("$name ($hits)")
done < <(join -o 1.2,1.3 <(awk '{ n = $1; sub(/^[^/]*\//, "", n); print n, $1, $2 }' "$w/merge.pkgs" | sort -k1,1) \
    <(names "$w/main.pkgs" | comm -13 - <(names "$w/merge.pkgs")))
allow="(.github/cachyos-sync-allowed, with why, if that's fine)"
((${#found[@]} == 0)) || held+=("it adds packages that start things by themselves $allow: ${found[*]}")

# What AgrOS relies on: agros-desktop's dependencies and the installer's, every level; the optional ones of the
# installer and of KPMcore (pacman -Si's "Optional Deps", a name each, its version and description taken off)
printf '%s\n' agros/agros-desktop agros/calamares >"$w/agros.list"
resolve "$w/agros.list" "$w/agros.pkgs"
[[ ! -s $w/agros.pkgs.unknown ]] || { echo "Not in [agros]: $(paste -sd' ' "$w/agros.pkgs.unknown")" >&2; exit 1; }
# (agros/calamares: whatever its package is named, by what it provides, as the ISO's list asks for it)
installer=$(pac -Sp --nodeps --nodeps --print-format '%r/%n' agros/calamares | grep '^[^ /]*/[^ /]*$')
{
    names "$w/agros.pkgs"
    # (a field's first line "<Field> : <value>", the rest of its values indented under it)
    pac -Si "$installer" kpmcore | awk '/^[^ ]/ { on = /^Optional Deps /; sub(/^[^:]*: /, "") }
        on { sub(/^ +/, ""); sub(/[:<>=].*/, ""); if ($0 != "None") print }'
} | sort -u >"$w/needed"
gone=$(names "$w/merge.pkgs" | comm -23 <(names "$w/main.pkgs") - | comm -12 - "$w/needed" | paste -sd' ')
[[ -z $gone ]] || held+=("it takes packages AgrOS relies on off the ISO: $gone")

why=$(printf '%s; ' "${held[@]}")
echo "why=${why%; }" >>"$out"
