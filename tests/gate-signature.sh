#!/usr/bin/env bash
# The upstream gate's list (agros-approved) taken only with a good signature by AgrOS's key beside it (agros's CI signs
# it): util.sh's gate_list (the build) stops on one with none, a bad one or another key's, as on one it can't fetch;
# agros-gate-install (the installer's step) takes it as unreachable, said: the ISO's own Hyprland put in. A key of the
# test's own as AgrOS's (agros.asc; agros-keyring's key file); curl, pacman-conf and pacman stand-ins
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
gpg --batch --export agros@agros.invalid >"$t/agros.gpg" 2>/dev/null
export AGROS_GATE_KEYRING=$t/agros.gpg
printf '#!/bin/sh\necho https://agros.invalid/x86_64\n' >"$t/bin/pacman-conf"
# curl: the list ($APPROVED) and its signature by AgrOS's key ($SIG: none, a 404; bad, of another list; other, another
# key's), each address past Pages' cache (?t=)
cat >"$t/bin/curl" <<'C'
#!/bin/bash
url=${*: -1}
echo "$url" >>"$CALLS"
[[ $url == *'?t='* ]] || exit 22
url=${url%%\?*}
out=/dev/stdout
while (($#)); do [[ $1 == -o ]] && out=$2; shift; done
if [[ $url != *.sig ]]; then printf '%s\n' "$APPROVED" >"$out"; exit 0; fi
case ${SIG:-} in
    none) exit 22 ;;
    bad) printf '%s\n' "$APPROVED" "hyprland 9.9.9" | gpg --batch --yes -u agros@agros.invalid --detach-sign -o "$out" 2>/dev/null ;;
    other) printf '%s\n' "$APPROVED" | gpg --batch --yes -u other@agros.invalid --detach-sign -o "$out" 2>/dev/null ;;
    *) printf '%s\n' "$APPROVED" | gpg --batch --yes -u agros@agros.invalid --detach-sign -o "$out" 2>/dev/null ;;
esac
C
chmod +x "$t/bin/"*
export CALLS=$t/calls APPROVED='hyprland 0.58.0'
export PATH=$t/bin:$PATH

# The build's gate_list
src_dir=$t/src
# shellcheck source=../util-msg.sh
. "$here/util-msg.sh"
# shellcheck source=../util.sh
. "$here/util.sh"
out=$(gate_list 2>&1) || fail "a signed list not taken by the build: $out"
[[ $out == 'hyprland 0.58.0' ]] || fail "not the signed list: $out"
grep -q '^https://agros.invalid/x86_64/agros-approved.sig?t=' "$CALLS" || fail "its signature not fetched past Pages' cache: $(cat "$CALLS")"
for sig in none bad other; do
    out=$(SIG=$sig gate_list 2>&1) && fail "a list with no good signature ($sig) taken by the build: $out"
    [[ $out == *"no good signature by AgrOS's key (https://agros.invalid/x86_64/agros-approved.sig)"* ]] ||
        fail "a list with no good signature ($sig) not said by the build: $out"
done

# The installer's agros-gate-install: the installed system's Hyprland 0.58.0 (newest), the ISO's copy 0.57.2
mkdir -p "$t/root/var/lib/pacman/local" "$t/copy"
: >"$t/copy/hyprland-0.57.2-1-x86_64.pkg.tar.zst"
# shellcheck disable=SC2016  # (expanded by the stand-in)
printf '#!/bin/bash\ncase "$1" in\n-Qp) echo "hyprland 0.57.2-1" ;;\n-Q) echo "hyprland 0.58.0-1" ;;\n*) echo "pacman $*" >>"$CALLS" ;;\nesac\n' >"$t/bin/pacman"
chmod +x "$t/bin/pacman"
install() { AGROS_GATE_COPY=$t/copy "$here/archiso/airootfs/usr/local/bin/agros-gate-install" "$t/root" 2>&1; }
out=$(install)
[[ $out == *"Hyprland as installed is approved"* ]] || fail "a signed list not taken by the installer: $out"
for sig in none bad other; do
    out=$(SIG=$sig install)
    [[ $out == *"the approved list has no good signature by AgrOS's key"* && $out == *"the ISO's own installed instead"* ]] ||
        fail "a list with no good signature ($sig) taken by the installer, or not said: $out"
done
echo "ok gate-signature"
