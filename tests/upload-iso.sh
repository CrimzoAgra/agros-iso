#!/usr/bin/env bash
# upload-iso.sh run with sudo (buildiso.sh -u), a dry run: it starts itself again as the user who ran sudo, and the
# SF_* settings in its environment still win, as its header says (sudo -u had dropped them: only upload.conf's left).
# Needs sudo without a password (GitHub's runners have it); without, skipped
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
if ! sudo -n true 2>/dev/null; then
    echo "ok upload-iso (skipped: no sudo without a password here)"
    exit 0
fi
iso=$t/agros-desktop-linux-261116-0900.iso
echo iso >"$iso"
(cd "$t" && sha256sum "${iso##*/}" >"${iso##*/}.sha256")
out=$(sudo -n env SF_USER=sfu SF_PROJECT=sfp SF_FOLDER=sff "$here/upload-iso.sh" -n "$iso" 2>&1) ||
    fail "a dry run under sudo failed: $out"
grep -qF 'sfu@frs.sourceforge.net:/home/frs/project/sfp/sff/' <<<"$out" || fail "the environment's settings lost under sudo: $out"
echo "ok upload-iso"
