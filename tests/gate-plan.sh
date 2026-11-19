#!/usr/bin/env bash
# util.sh's gate_plan (the upstream gate's look at the ISO's packages, the build's and the ISO workflow's first
# resolution of its package list): the gated packages the ISO gets; a name in the list the repos don't have (CachyOS
# dropped it, or [agros] hasn't published it yet) stops it saying which, as pacman said it (it stopped with no name,
# pacman's own message thrown away). sudo and pacman stand-ins
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
mkdir -p "$t/bin" "$t/src/archiso"
printf '#!/bin/sh\nexec "$@"\n' >"$t/bin/sudo"
# (pacman: -Sy fine; -Sp resolves the list on its input, every name the "repos" have but agros-missing)
cat >"$t/bin/pacman" <<'EOF'
#!/bin/bash
case $1 in
    -Sy) exit 0 ;;
    -Sp)
        list=$(cat)
        if grep -qx agros-missing <<<"$list"; then echo "error: target not found: agros-missing" >&2; exit 1; fi
        printf '%s\n' "hyprland 0.57.2-1" "foot 1.25.0-1" ;;
esac
EOF
chmod +x "$t/bin/"*
export PATH=$t/bin:$PATH
src_dir=$t/src
# shellcheck source=../util-msg.sh
. "$here/util-msg.sh"
# shellcheck source=../util.sh
. "$here/util.sh"
printf '%s\n' hyprland foot >"$t/src/archiso/packages_desktop.x86_64"
out=$( (gate_plan "hyprland 0.57.2") 2>&1) || fail "a list the repos have not looked up: $out"
[[ $out == "hyprland 0.57.2-1" ]] || fail "not the gated packages the ISO gets: $out"
printf '%s\n' hyprland agros-missing >"$t/src/archiso/packages_desktop.x86_64"
! out=$( (gate_plan "hyprland 0.57.2") 2>&1) || fail "a name the repos don't have not caught: $out"
[[ $out == *"couldn't be looked up (for the upstream gate): target not found: agros-missing"* ]] ||
    fail "the name the repos don't have not said: $out"
echo "ok gate-plan"
