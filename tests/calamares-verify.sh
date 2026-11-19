#!/usr/bin/env bash
# util-iso.sh's calamares_verify (the build, once mkarchiso has made the live system): AgrOS's settings for the
# installer (agros-calamares-config) tried on the ISO's own installer, on a copy of its files. Settings that apply: the
# build goes on, the installer's files untouched, its notes warnings ending in "(agros-calamares-config)"; a script the
# install runs looked for in the live system's files, not the build machine's (AGROS_ROOT). One that no longer applies
# (CachyOS's installer moved it): the build stops, saying which, as the installer would have stopped on every machine.
# And the build checks it before the ISO takes its name
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
# shellcheck source=../util-msg.sh
. "$here/util-msg.sh"
# shellcheck source=../util-iso.sh
. "$here/util-iso.sh"
r=$t/airootfs
# The live system's files as the installer's package and the profile leave them (the lines agros-calamares-config reads)
setup() {
    rm -rf "$r"
    mkdir -p "$r/usr/share/calamares" "$r/etc/calamares/modules" "$r/usr/local/bin"
    for m in pacstrap grubcfg bootloader; do mkdir -p "$r/usr/lib/calamares/modules/$m"; done
    cp "$here/archiso/airootfs/usr/local/bin/agros-calamares-config" "$r/usr/local/bin/"
    printf '%s\n' 'sequence:' '- show:' '  - welcome@online' '  - packagechooser@bootloader' '- exec:' \
        '  - shellprocess@btrfs_snapshot' '  - shellprocess@cleanup_calamares' 'branding: cachyos' 'instances:' \
        '- id: cleanup_calamares' '  module: shellprocess' '  config: shellprocess_cleanup.conf' \
        >"$r/usr/share/calamares/settings_online.conf"
    printf '%s\n' 'efiBootLoaderVar: "packagechooser_bootloader"' 'efiBootLoader: "limine"' 'efiBootloaderId: "cachyos"' \
        >"$r/etc/calamares/modules/bootloader.conf"
    printf '%s\n' 'efiSystemPartition:     "/boot"' 'efiSystemPartitionSize:     2048M' 'allowZfsEncryption: true' \
        >"$r/etc/calamares/modules/partition.conf"
    printf '%s\n' '---' 'requirements:' '    requiredStorage:    8.0' >"$r/etc/calamares/modules/welcome_online.conf"
    for m in pacstrap grubcfg; do
        echo '    bootloader = libcalamares.globalstorage.value("packagechooser_bootloader")' \
            >"$r/usr/lib/calamares/modules/$m/main.py"
    done
    printf '%s\n' 'def install_grub(efi_directory, fw_type, install_hybrid_grub):' \
        '        if libcalamares.job.configuration.get(fallback, True):' '            pass' \
        >"$r/usr/lib/calamares/modules/bootloader/main.py"
    # (a script of the live system's own that the install runs, which the build machine doesn't have)
    printf '%s\n' '---' 'script:' '    - command: "/usr/local/bin/agros-test-live-only"' \
        >"$r/etc/calamares/modules/shellprocess_cleanup.conf"
    : >"$r/usr/local/bin/agros-test-live-only"
}
verify() { (calamares_verify "$r") 2>&1; }

setup
before=$(cd "$r" && find . -type f -exec sha256sum {} + | sort)
out=$(verify) || fail "settings that apply stopped the build: $out"
[[ $(cd "$r" && find . -type f -exec sha256sum {} + | sort) == "$before" ]] || fail "the installer's own files changed"
# (its note, the room left as CachyOS has it: a warning, said as agros-calamares-config's)
setup
printf '%s\n' '---' 'requirements:' '    requiredRam:        2.5' >"$r/etc/calamares/modules/welcome_online.conf"
out=$(verify) || fail "a note stopped the build: $out"
grep -q "WARNING: the room the installer asks for left as CachyOS has it (agros-calamares-config)" <<<"$out" ||
    fail "the note not a warning: $out"
grep -q 'installer configured' <<<"$out" && fail "its last line said as a warning: $out"
# A script the install runs that the live system lacks (on the build machine or not): the build stops, saying which
setup
rm "$r/usr/local/bin/agros-test-live-only"
! out=$(verify) || fail "a script the live system lacks not caught: $out"
grep -q "installer couldn't be set up: AgrOS: the installer runs /usr/local/bin/agros-test-live-only" <<<"$out" ||
    fail "not said: $out"
# A setting moved (the bootloader step's): the build stops, saying which
setup
sed -i '/^efiBootLoader: /d' "$r/etc/calamares/modules/bootloader.conf"
! out=$(verify) || fail "a setting that no longer applies not caught: $out"
grep -q "installer couldn't be set up: AgrOS: the bootloader step isn't set to GRUB" <<<"$out" || fail "not said: $out"
# No installer settings where calamares-online.sh takes them: the build stops
setup
rm "$r/usr/share/calamares/settings_online.conf"
! out=$(verify) || fail "no installer settings not caught: $out"
grep -q "no settings where calamares-online.sh takes them" <<<"$out" || fail "not said: $out"

# The build checks it on mkarchiso's tree, the ISO deleted when it fails, before the ISO takes its name
body=$(sed -n '/^run_build()/,/^}/p' "$here/util-iso.sh")
grep -q 'calamares_verify "${work_dir}/x86_64/airootfs" ) ||$' <<<"$body" || fail "run_build doesn't check the installer"
[[ $(grep -n 'calamares_verify\|mv "${_built\[0\]}"' <<<"$body" | cut -d: -f1 | paste -sd' ') =~ ^([0-9]+)\ ([0-9]+)$ ]] &&
    ((BASH_REMATCH[1] < BASH_REMATCH[2])) || fail "the installer checked after the ISO took its name"
echo "ok calamares-verify"
