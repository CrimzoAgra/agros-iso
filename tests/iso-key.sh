#!/usr/bin/env bash
# iso.yml's "What changed" key, which "Already published?" looks up (a run agros's CI starts skips an ISO already out):
# the files on.push.paths lets through and [agros]'s packages. A change to the docs, the tests or another workflow
# leaves it as it was; one to the profile, a script the build runs or iso.yml itself, or a package (a rebuild under the
# same version too: its checksum), makes a new one. The step's own commands, read from the workflow, curl stubbed
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
awk '/^      - name: What changed$/ { s = 1 } s && /^        run: \|$/ { on = 1; next } on && !/^          / && !/^$/ { exit }
    on { sub(/^          /, ""); print }' "$here/.github/workflows/iso.yml" | tr -d '\r' >"$t/step.sh"
grep -q 'key=iso-published-' "$t/step.sh" || fail "the What changed step's commands not found in iso.yml"
mkdir -p "$t/bin" "$t/r/.github/workflows" "$t/r/archiso" "$t/r/docs" "$t/r/tests"
cp "$here/.github/workflows/iso.yml" "$t/r/.github/workflows/"
# (curl: the database, whatever's asked for, into -o's file)
cat >"$t/bin/curl" <<SH
#!/bin/bash
while (((\$#))); do [[ \$1 == -o ]] && { cp "$t/agros.db" "\$2"; shift; }; shift; done
SH
chmod +x "$t/bin/curl"
# db <sum>: a database with one package of that checksum
db() { rm -rf "$t/d" && mkdir -p "$t/d/x-1-1" && printf '%%SHA256SUM%%\n%s\n' "$1" >"$t/d/x-1-1/desc" && tar -czf "$t/agros.db" -C "$t/d" x-1-1; }
git_() { git -C "$t/r" -c user.name=t -c user.email=t@t "$@"; }
key() {
    git_ add -A && git_ commit -qm x --allow-empty
    (cd "$t/r" && PATH=$t/bin:$PATH GITHUB_EVENT_NAME=workflow_dispatch GITHUB_OUTPUT=$t/out bash -eo pipefail "$t/step.sh" >/dev/null) ||
        fail "the step failed"
    sed -n 's/^key=//p' "$t/out" | tail -n1
}
git_ init -q
echo a >"$t/r/archiso/packages_desktop.x86_64"; echo a >"$t/r/README.md"; echo a >"$t/r/buildiso.sh"
db aaa
k0=$(key)
[[ $k0 =~ ^iso-published-[0-9a-f]{16}-[0-9a-f]{16}$ ]] || fail "not a key: $k0"
echo b >"$t/r/README.md"; echo b >"$t/r/docs/x.md"; echo b >"$t/r/tests/x.sh"; echo b >"$t/r/.github/workflows/tests.yml"
[[ $(key) == "$k0" ]] || fail "the docs, the tests or another workflow changed the key"
echo b >"$t/r/archiso/packages_desktop.x86_64"
k1=$(key)
[[ $k1 != "$k0" ]] || fail "a change to the profile kept the key"
echo b >"$t/r/buildiso.sh"
k2=$(key)
[[ $k2 != "$k1" ]] || fail "a change to the build's script kept the key"
echo '# x' >>"$t/r/.github/workflows/iso.yml"
k3=$(key)
[[ $k3 != "$k2" ]] || fail "a change to iso.yml kept the key"
db bbb
[[ $(key) != "$k3" && $(key) == "${k3%-*}-"* ]] || fail "a rebuilt package kept the key, or changed the files' half"
echo "ok iso-key"
