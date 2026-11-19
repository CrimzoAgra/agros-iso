#!/usr/bin/env bash
# The ISO workflow's step that gets CachyOS's keyring for the build: from the servers the build's pacman.conf has for
# [cachyos], each in turn (the first down, HTTP 521, failed the whole build there although mkarchiso would have used
# the next), its file named by the repo's database (a mirror with no folder listing serves that too); every server
# failing, or a database without the keyring, fails the step, said. The step's own commands, read from the workflow,
# with curl (two made-up servers, one down), pacman-conf and pacman-key stubbed
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
tr -d '\r' <"$here/.github/workflows/iso.yml" |
    awk '/^      - name: Build tools, and CachyOS.s and AgrOS.s keys$/ { step = 1; next } step && /^      - / { exit }
        step && /^        run: \|$/ { on = 1; next } on { sub(/^          /, ""); print }' >"$t/step.sh"
grep -q 'pacman-key --lsign-key' "$t/step.sh" || fail "the keyring step's commands not found in iso.yml"
mkdir -p "$t/bin" "$t/srv/up" "$t/w" "$t/tmp"
# (curl -o <file> <url>: https://up/<path> served from $t/srv/up, anything else down)
cat >"$t/bin/curl" <<'EOF'
#!/usr/bin/env bash
out= url=
while (($#)); do case $1 in -o) out=$2; shift 2 ;; *) url=$1; shift ;; esac; done
echo "$url" >>"$T/curl.log"
[[ $url == https://up/* && -f $T/srv/up/${url#https://up/} ]] || { echo "curl: (22) error: 521" >&2; exit 22; }
cp "$T/srv/up/${url#https://up/}" "$out"
EOF
cat >"$t/bin/pacman-conf" <<'EOF'
#!/bin/sh
[ "$*" = "--config archiso/pacman.conf --repo cachyos Server" ] || { echo "pacman-conf $*?" >&2; exit 1; }
printf '%s\n' $SERVERS
EOF
# (pacman-key: its calls, and the keyring file it was given)
printf '#!/bin/sh\necho "$*" >>"$T/keys.log"\n[ "$1" != --add ] || cat "$2" >>"$T/keys.log"\n' >"$t/bin/pacman-key"
printf '#!/bin/sh\nexit 0\n' >"$t/bin/pacman"
printf '#!/bin/sh\nexit 0\n' >"$t/bin/df"
command -v bsdtar >/dev/null || printf '#!/bin/sh\nexec tar "$@"\n' >"$t/bin/bsdtar"
chmod +x "$t/bin/"*
# The repo: its database (the keyring and another package, a desc each) and the keyring package
mkdir -p "$t/db/cachyos-hooks-1-1" "$t/db/cachyos-keyring-20240331-1" "$t/pkg/usr/share/pacman/keyrings"
printf '%%FILENAME%%\ncachyos-hooks-1-1-any.pkg.tar.zst\n\n%%NAME%%\ncachyos-hooks\n' >"$t/db/cachyos-hooks-1-1/desc"
printf '%%FILENAME%%\ncachyos-keyring-20240331-1-any.pkg.tar.zst\n\n%%NAME%%\ncachyos-keyring\n' \
    >"$t/db/cachyos-keyring-20240331-1/desc"
echo "CachyOS's keys" >"$t/pkg/usr/share/pacman/keyrings/cachyos.gpg"
(cd "$t/db" && tar -cf "$t/srv/up/cachyos.db" -- *)
(cd "$t/pkg" && tar -cf "$t/srv/up/cachyos-keyring-20240331-1-any.pkg.tar.zst" usr)
# step <servers>: the step run as GitHub runs it, its status in $rc, its output in $out
step() {
    rm -f "$t/curl.log" "$t/keys.log"
    rc=0
    out=$(cd "$t/w" && T=$t SERVERS=$1 TMPDIR=$t/tmp PATH=$t/bin:$PATH bash -eo pipefail "$t/step.sh" 2>&1) || rc=$?
}

# CachyOS's own server down: the keyring from the next, its keys added and the key trusted
step "https://down/cachyos https://up"
((rc == 0)) || fail "the first server down failed the step: $out"
grep -q '::warning::.*https://down/cachyos' <<<"$out" || fail "the server that failed not said: $out"
grep -qx "https://up/cachyos-keyring-20240331-1-any.pkg.tar.zst" "$t/curl.log" ||
    fail "the keyring not fetched by its database's name: $(cat "$t/curl.log")"
grep -qx "CachyOS's keys" "$t/keys.log" &&
    grep -qx -- '--lsign-key 882DCFE48E2051D48E2562ABF3B607488DB35A47' "$t/keys.log" ||
    fail "the keyring's keys not added and trusted: $(cat "$t/keys.log" 2>/dev/null)"
# The first one up: the second never asked
step "https://up https://down/cachyos"
((rc == 0)) && ! grep -q down "$t/curl.log" || fail "the first server up: rc $rc, $(cat "$t/curl.log")"
# Every one down: the step fails, said, no key added
step "https://down/a https://down/b"
((rc != 0)) && grep -q "::error::No cachyos-keyring" <<<"$out" && [[ ! -e $t/keys.log ]] ||
    fail "every server down: rc $rc, $out"
# A database without the keyring: as a server down
rm -rf "$t/db/cachyos-keyring-20240331-1" && (cd "$t/db" && tar -cf "$t/srv/up/cachyos.db" -- *)
step "https://up"
((rc != 0)) && [[ ! -e $t/keys.log ]] || fail "no keyring in the database: rc $rc, $out"
echo "ok build-keyring"
