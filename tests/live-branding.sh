#!/usr/bin/env bash
# The live system's name: what CachyOS's hooks left in os-release and lsb-release (as on the 261116-2139 ISO) becomes
# AgrOS's, and the hook runs after CachyOS's and before the removal of the build-only hooks (pacman: name order)
source "$(dirname "$0")/lib.sh"
hooks=$here/archiso/airootfs/etc/pacman.d/hooks
printf '%s\n' 'NAME="CachyOS Linux"' 'PRETTY_NAME="CachyOS"' 'ID=cachyos' 'ID_LIKE=arch' 'BUILD_ID=rolling' \
    'ANSI_COLOR="38;2;23;147;209"' 'HOME_URL="https://cachyos.org/"' 'LOGO=cachyos' >"$t/os"
printf '%s\n' 'DISTRIB_ID=cachyos' 'DISTRIB_RELEASE="rolling"' 'DISTRIB_DESCRIPTION="CachyOS"' >"$t/lsb"
bash "$hooks/agros-live-branding" "$t/os" "$t/lsb" || fail "the script failed"
want=('NAME="AgrOS"' 'PRETTY_NAME="AgrOS"' 'ID=agros' 'ID_LIKE="cachyos arch"' 'BUILD_ID=rolling' 'LOGO=agros-logo'
    'HOME_URL="https://github.com/CrimzoAgra/agros"')
for l in "${want[@]}"; do grep -qxF "$l" "$t/os" || fail "no $l in os-release: $(cat "$t/os")"; done
! grep -qi cachyos.org "$t/os" || fail "CachyOS's still in os-release: $(cat "$t/os")"
grep -qx 'DISTRIB_ID=agros' "$t/lsb" && grep -qx 'DISTRIB_DESCRIPTION="AgrOS"' "$t/lsb" ||
    fail "not AgrOS's lsb-release: $(cat "$t/lsb")"
# (CachyOS's hooks that write the name, and the one removing the build-only hooks: pacman sorts by name, as C does)
order=$(printf '%s\n' cachyos-branding.hook lsb-release.hook os-release.hook zz-agros-live-branding.hook \
    zzzz99-remove-custom-hooks-from-airootfs.hook | LC_ALL=C sort | tr '\n' ' ')
[[ $order == *"os-release.hook zz-agros-live-branding.hook zzzz99-"* ]] || fail "the hook runs out of order: $order"
for f in zz-agros-live-branding.hook agros-live-branding; do
    grep -qF 'remove from airootfs' "$hooks/$f" || fail "$f stays on the live system"
done
grep -qx 'Exec = /usr/bin/bash /etc/pacman.d/hooks/agros-live-branding' "$hooks/zz-agros-live-branding.hook" ||
    fail "the hook doesn't run the script"
echo "ok live-branding"
