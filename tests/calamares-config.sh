#!/usr/bin/env bash
# agros-calamares-config: the EFI partition minimum (installed beside Windows: its own 100 MB EFI partition used, not refused
# below the 512 MB a new one is made): set where CachyOS's partition.conf has no efi block, added to one it has (in the
# block's own indentation, or YAML fails and so does the installer), a minimum of theirs kept, once over two runs, and
# an efi of theirs written on one line left alone with the installer still configured. And CachyOS's ISO scripts AgrOS's
# ISO lacks (dmcheck, remove-nvidia) out of what the install copies and runs, any other it would run caught before it
# starts. On copies of CachyOS's files' lines it reads (settings.conf, bootloader.conf, partition.conf, pacstrap.conf,
# shellprocess.conf, the bootloader choice in two Python steps)
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
cfg=$here/archiso/airootfs/usr/local/bin/agros-calamares-config
# A fresh copy of the installer's files, with CachyOS's partition.conf followed by $1 (its efi block, if any)
setup() {
    rm -rf "$t/c"
    mkdir -p "$t/c/modules" "$t/c/py/pacstrap" "$t/c/py/grubcfg" "$t/c/py/chwd"
    printf '%s\n' 'sequence:' '- show:' '  - welcome' '  - packagechooser@bootloader' '- exec:' \
        '  - shellprocess@btrfs_snapshot' '  - shellprocess@cleanup_calamares' 'branding: cachyos' 'instances:' \
        '- id: cleanup_calamares' '  module: shellprocess' '  config: shellprocess_cleanup.conf' >"$t/c/settings.conf"
    printf '%s\n' 'efiBootLoaderVar: "packagechooser_bootloader"' 'efiBootLoader: "limine"' 'efiBootloaderId: "cachyos"' \
        >"$t/c/modules/bootloader.conf"
    printf '%s\n' 'efiSystemPartition:     "/boot"' 'efiSystemPartitionSize:     2048M' 'allowZfsEncryption: true' "$1" \
        >"$t/c/modules/partition.conf"
    for m in pacstrap grubcfg chwd; do
        echo '    bootloader = libcalamares.globalstorage.value("packagechooser_bootloader")' >"$t/c/py/$m/main.py"
    done
}
run() { bash "$cfg" "$t/c/settings.conf" "$t/c/modules" "$t/c/py" 2>&1; }
p=$t/c/modules/partition.conf
# (YAML's own reading, where python's yaml is there: the installer would stop on a file that doesn't parse)
parses() { ! python3 -c 'import yaml' 2>/dev/null || python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "${1:-$p}"; }

# No efi block (CachyOS's today): one added, once over two runs
setup ""
out=$(run) && out=$(run) || fail "it failed: $out"
[[ $(grep -c '^efi:' "$p") == 1 && $(grep -c '^  minimumSize: 64M$' "$p") == 1 ]] || fail "the minimum not set once: $(cat "$p")"
grep -q '^efiSystemPartitionSize: *512M' "$p" || fail "a new EFI partition isn't 512 MB any more: $(cat "$p")"
parses || fail "partition.conf no longer YAML: $(cat "$p")"
# An efi block of theirs, its keys indented by four: the minimum under it, as indented
setup $'efi:\n    recommendedSize: 1024MiB'
out=$(run) || fail "it failed with an efi block: $out"
[[ $(sed -n '/^efi:$/{n;p;q;}' "$p") == '    minimumSize: 64M' && $(grep -c '^efi:' "$p") == 1 ]] ||
    fail "the minimum not added under their efi block, as indented: $(cat "$p")"
parses || fail "partition.conf no longer YAML: $(cat "$p")"
# A minimum of theirs: kept
setup $'efi:\n  minimumSize: 300MiB'
out=$(run) || fail "it failed with their minimum: $out"
[[ $(grep -c 'minimumSize' "$p") == 1 ]] && grep -q '^  minimumSize: 300MiB$' "$p" || fail "their minimum not kept: $(cat "$p")"
# Their efi on one line: left alone (no second efi key), said, and the installer configured all the same
setup 'efi: { recommendedSize: 1024MiB }'
out=$(run) || fail "it failed with an efi on one line: $out"
[[ $(grep -c '^efi:' "$p") == 1 ]] || fail "a second efi key added: $(cat "$p")"
grep -q "minimum size left as CachyOS has it" <<<"$out" && grep -q 'installer configured' <<<"$out" ||
    fail "not said, or not configured: $out"

# CachyOS's dmcheck and remove-nvidia (scripts of its ISO, not AgrOS's): out of what the install copies and runs, with a
# command's own keys under it, every other item kept, and the files still YAML (as the cachyos branch has them)
setup ""
sp=$t/c/modules/shellprocess.conf ps=$t/c/modules/pacstrap.conf
printf '%s\n' '---' 'postInstallFiles:' '  - "/etc/mkinitcpio.conf"' '  - "/usr/local/bin/dmcheck"' \
    '  - "/usr/local/bin/remove-nvidia"' '  - "/etc/calamares/scripts/enable-ufw"' >"$ps"
printf '%s\n' '---' 'script:' '    - "-rm /etc/systemd/system/display-manager.service"' '    - command: "/usr/local/bin/dmcheck"' \
    '      timeout: 30' '    - "-rm /usr/local/bin/dmcheck"' '    - "-rm -rf /home/liveuser"' \
    '    - command: "/etc/calamares/scripts/shell-setup"' '      verbose: true' >"$sp"
out=$(run) || fail "it failed with CachyOS's dmcheck: $out"
[[ $(cat "$ps") == $'---\npostInstallFiles:\n  - "/etc/mkinitcpio.conf"\n  - "/etc/calamares/scripts/enable-ufw"' ]] ||
    fail "pacstrap.conf not without them alone: $(cat "$ps")"
[[ $(cat "$sp") == $'---\nscript:\n    - "-rm /etc/systemd/system/display-manager.service"\n    - "-rm -rf /home/liveuser"\n    - command: "/etc/calamares/scripts/shell-setup"\n      verbose: true' ]] ||
    fail "shellprocess.conf not without dmcheck alone: $(cat "$sp")"
parses "$ps" && parses "$sp" || fail "pacstrap.conf or shellprocess.conf no longer YAML"
# Another script of CachyOS's ISO the install would run (the plain step's, or one in settings.conf): the installer not
# started, said; one allowed to fail ("-"): no matter
setup ""
printf '%s\n' '---' 'script:' '    - "-/usr/local/bin/agros-test-not-here"' '    - command: "-/usr/local/bin/agros-test-not-here x"' >"$sp"
out=$(run) || fail "a command allowed to fail stopped it: $out"
printf '%s\n' '---' 'script:' '    - command: "/usr/local/bin/agros-test-not-here"' >"$t/c/modules/shellprocess_cleanup.conf"
! out=$(run) || fail "a command the ISO lacks not caught: $out"
grep -q "runs /usr/local/bin/agros-test-not-here, which this ISO doesn't have" <<<"$out" || fail "not said: $out"
echo "ok calamares-config"
