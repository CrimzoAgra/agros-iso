#!/usr/bin/env bash
# util.sh's newest_iso (testiso.sh's ISO to boot, upload-iso.sh's with none given, the ISO workflow's to sign): the
# newest finished one, a test build's too, never the one a stopped build left half-written under mkarchiso's name
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
src_dir=$t
# shellcheck source=../util.sh
. "$here/util.sh"
o=$t/out/desktop
mkdir -p "$o"
[[ -z $(newest_iso) ]] || fail "an ISO found in an empty folder"
touch -d '-2 hours' "$o/agros-desktop-linux-261116-0900.iso" "$o/agros-desktop-linux-261116-0900.iso.sha256"
touch -d '-1 hour' "$o/agros-desktop-linux-261116-1000-ungated.iso"
touch "$o/agros-2026.11.16-x86_64.iso"
[[ $(newest_iso) == "$o/agros-desktop-linux-261116-1000-ungated.iso" ]] || fail "newest_iso: $(newest_iso)"
[[ $(newest_iso "$o") == "$o/agros-desktop-linux-261116-1000-ungated.iso" ]] || fail "newest_iso <dir>: $(newest_iso "$o")"
rm "$o/agros-desktop-linux-261116-1000-ungated.iso"
[[ $(newest_iso) == "$o/agros-desktop-linux-261116-0900.iso" ]] || fail "newest_iso, the test build gone: $(newest_iso)"
echo "ok newest-iso"
