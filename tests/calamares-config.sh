#!/usr/bin/env bash
# agros-calamares-config: the EFI partition minimum (installed beside Windows: its own 100 MB EFI partition used, not refused
# below the 512 MB a new one is made): set where CachyOS's partition.conf has no efi block, added to one it has (in the
# block's own indentation, or YAML fails and so does the installer), a minimum of theirs kept, once over two runs, and
# an efi of theirs written on one line left alone with the installer still configured. And CachyOS's ISO scripts AgrOS's
# ISO lacks (dmcheck, remove-nvidia) out of what the install copies and runs, any other it would run caught before it
# starts. And the room the installer asks for, AgrOS's. On copies of CachyOS's files' lines it reads (settings.conf,
# bootloader.conf, partition.conf, welcome_online.conf, pacstrap.conf, shellprocess.conf, the bootloader choice in two
# Python steps, the fallback loader's copy in a third)
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
cfg=$here/archiso/airootfs/usr/local/bin/agros-calamares-config
# A fresh copy of the installer's files, with CachyOS's partition.conf followed by $1 (its efi block, if any), and
# $snapstep (CachyOS's btrfs snapshot step) in its sequence
setup() {
    rm -rf "$t/c"
    mkdir -p "$t/c/modules" "$t/c/py/pacstrap" "$t/c/py/grubcfg"
    printf '%s\n' 'sequence:' '- show:' '  - welcome' '  - packagechooser@bootloader' '- exec:' \
        "$snapstep" '  - shellprocess@cleanup_calamares' 'branding: cachyos' 'instances:' \
        '- id: cleanup_calamares' '  module: shellprocess' '  config: shellprocess_cleanup.conf' >"$t/c/settings.conf"
    printf '%s\n' 'efiBootLoaderVar: "packagechooser_bootloader"' 'efiBootLoader: "limine"' 'efiBootloaderId: "cachyos"' \
        >"$t/c/modules/bootloader.conf"
    printf '%s\n' 'efiSystemPartition:     "/boot"' 'efiSystemPartitionSize:     2048M' 'allowZfsEncryption: true' "$1" \
        >"$t/c/modules/partition.conf"
    printf '%s\n' '---' 'requirements:' '    requiredStorage:    8.0' '    requiredRam:        2.5' >"$t/c/modules/welcome_online.conf"
    for m in pacstrap grubcfg; do
        echo '    bootloader = libcalamares.globalstorage.value("packagechooser_bootloader")' >"$t/c/py/$m/main.py"
    done
    # (the bootloader step's GRUB copy over the firmware's fallback loader, as their main.py has it)
    mkdir -p "$t/c/py/bootloader"
    printf '%s\n' '        fallback = "installEFIFallback"' '        if libcalamares.job.configuration.get(fallback, True):' \
        '            shutil.copy2(efi_file_source, efi_file_target)' >"$t/c/py/bootloader/main.py"
}
snapstep="  - shellprocess@btrfs_snapshot"
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
# The room AgrOS needs (the welcome page's, and the least the partition page leaves beside Windows): set, CachyOS's other
# requirements kept, still YAML; their setting gone: said, the installer configured all the same
w=$t/c/modules/welcome_online.conf
[[ $(cat "$w") == $'---\nrequirements:\n    requiredStorage:    20.0\n    requiredRam:        2.5' ]] ||
    fail "the room the installer asks for not AgrOS's: $(cat "$w")"
parses "$w" || fail "welcome_online.conf no longer YAML: $(cat "$w")"
grep -q "room the installer asks for" <<<"$out" && fail "said as not set, though it was: $out"
setup ""
printf '%s\n' '---' 'requirements:' '    requiredRam:        2.5' >"$w"
out=$(run) || fail "it failed with no room setting: $out"
grep -q "room the installer asks for left as CachyOS has it" <<<"$out" && grep -q 'installer configured' <<<"$out" ||
    fail "no room setting not said, or not configured: $out"
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

# The login screen's step before the btrfs snapshot, and AgrOS's step naming the snapshot right after it, whichever
# module takes it: a shellprocess script (the cachyos branch) or gucc, their installer's own code (cachyos-staging);
# once over two runs, settings.conf still YAML, and no dollar sign in AgrOS's command
s=$t/c/settings.conf
for snapstep in "  - shellprocess@btrfs_snapshot" "  - gucc@btrfs_snapshot"; do
    setup ""
    out=$(run) && out=$(run) || fail "it failed with ${snapstep##* }: $out"
    [[ $(sed -n '/^- exec:$/,/^branding:/p' "$s" | sed -n 's/^  - //p' | paste -sd' ') == \
        "shellprocess@agrosgate shellprocess@greetd ${snapstep##* } shellprocess@agrossnapshot shellprocess@cleanup_calamares" ]] ||
        fail "the steps around ${snapstep##* } not in order: $(cat "$s")"
    [[ $(grep -c '^- id: *agrossnapshot$' "$s") == 1 ]] || fail "the snapshot step's instance not there once: $(cat "$s")"
    parses "$s" && parses "$t/c/modules/shellprocess_agrossnapshot.conf" || fail "settings.conf or the snapshot step no longer YAML"
    ! grep -q '\$' "$t/c/modules/shellprocess_agrossnapshot.conf" || fail "a dollar sign in the snapshot step's command"
done
# No snapshot step: the login screen's before the clean-up, none naming a snapshot, said
snapstep="  - shellprocess@initcpio"
setup ""
out=$(run) || fail "it failed with no snapshot step: $out"
[[ $(sed -n 's/^  - shellprocess@//p' "$s" | paste -sd' ') == "initcpio agrosgate greetd cleanup_calamares" ]] &&
    ! grep -q agrossnapshot "$s" || fail "not set up as with no snapshot: $(cat "$s")"
grep -q "no btrfs snapshot step" <<<"$out" || fail "not said: $out"
# CachyOS's own greetd step after their snapshot (it'd delete it): the installer not started, said
snapstep=$'  - gucc@btrfs_snapshot\n  - shellprocess@greetd'
setup ""
printf '%s\n' '- id: greetd' '  module: shellprocess' '  config: shellprocess_greetd.conf' >>"$s"
! out=$(run) || fail "a greetd step after the snapshot not caught: $out"
grep -q "greetd step is after the btrfs snapshot" <<<"$out" || fail "not said: $out"

# The login screen's step has CachyOS's own steps' hour (it rebuilds both kernels' initramfs): cut off, the install fails
snapstep="  - shellprocess@btrfs_snapshot"
setup ""
out=$(run) || fail "it failed: $out"
grep -qx 'timeout: 3600' "$t/c/modules/shellprocess_greetd.conf" || fail "the greetd step's time isn't an hour"

# No "Log in automatically" box (greetd's login screen isn't set up by the step it's for): one CachyOS turned on, off
setup ""
printf '%s\n' '---' 'doAutoLogin: true' 'displayAutologin: true' 'sudoersGroup: wheel' >"$t/c/modules/users.conf"
out=$(run) || fail "it failed with autologin on: $out"
[[ $(cat "$t/c/modules/users.conf") == $'---\ndoAutoLogin: false\ndisplayAutologin: false\nsudoersGroup: wheel' ]] ||
    fail "the autologin box not kept off: $(cat "$t/c/modules/users.conf")"

# AgrOS's snapshot step's own command, run with snapper stubbed (its list, the renames it was asked for) and its
# temporary files in the test's folder: the installation's snapshot renamed; none described so, said, none renamed
cmd=$t/snapcmd.sh
awk '/^ - command: \|$/ { on = 1; next } on && /^[^ ]/ { on = 0 } on { sub(/^      /, ""); print }' \
    "$t/c/modules/shellprocess_agrossnapshot.conf" | sed "s|/tmp/|$t/tmp/|g" >"$cmd"
grep -q 'snapper' "$cmd" || fail "the snapshot step's command not read: $(cat "$t/c/modules/shellprocess_agrossnapshot.conf")"
mkdir -p "$t/tmp" "$t/sbin"
# shellcheck disable=SC2016  # (the stub's own variables)
printf '%s\n' '#!/bin/sh' 'case "$*" in' '  *" list "*) printf "%b" "$SNAPS" ;;' \
    "  *\" modify \"*) echo \"\$*\" >>\"$t/renamed\" ;;" 'esac' >"$t/sbin/snapper"
# (and GRUB's menu not made again: on a machine with grub-btrfs the command would remake the machine's own)
printf '%s\n' '#!/bin/sh' 'exit 0' >"$t/sbin/grub-mkconfig"
chmod +x "$t/sbin/snapper" "$t/sbin/grub-mkconfig"
snap() { rm -f "$t/renamed"; SNAPS=$1 PATH=$t/sbin:$PATH sh "$cmd" 2>&1; }
out=$(snap 'number,description\n0,current\n1,Fresh CachyOS Installation\n2,pre\n')
[[ $(cat "$t/renamed" 2>/dev/null) == "--no-dbus -c root modify --description Fresh AgrOS Installation 1" ]] ||
    fail "the installation snapshot not renamed: $(cat "$t/renamed" 2>/dev/null) ($out)"
[[ -z $out ]] || fail "a rename said something: $out"
out=$(snap 'number,description\n0,current\n1,Fresh CachyOS install\n')
[[ ! -e $t/renamed ]] || fail "a snapshot renamed though none is the installation's: $(cat "$t/renamed")"
grep -q "no snapshot described as the installation's" <<<"$out" || fail "no installation snapshot, not said: $out"
[[ -z $(ls -A "$t/tmp") ]] || fail "the step's temporary files left: $(ls -A "$t/tmp")"

# Beside Windows, the firmware's fallback loader kept: GRUB copied over it only with no Windows boot manager on the boot
# partition (the patched condition run as the step would, where python3 is there), once over two runs. The step changed
# by CachyOS: said, the installer configured all the same
setup ""
out=$(run) && out=$(run) || fail "it failed: $out"
b=$t/c/py/bootloader/main.py
[[ $(grep -c 'bootmgfw' "$b") == 1 ]] || fail "the fallback copy not made conditional, once: $(cat "$b")"
grep -q "fallback loader" <<<"$out" && fail "said as not patched, though it was: $out"
cond=$(sed -n 's/^ *if \(libcalamares\.job\.configuration\.get(fallback, True) and .*\):$/\1/p' "$b")
[[ -n $cond ]] || fail "the patched condition not found: $(cat "$b")"
if python3 -c 'import os' 2>/dev/null; then
    # copies <esp>: the step's condition on that EFI folder, True when GRUB would be copied over the fallback loader
    copies() {
        python3 -c 'import os, sys
class job: configuration = {"installEFIFallback": True}
class libcalamares: job = job
fallback, install_efi_directory_firmware = "installEFIFallback", sys.argv[2]
print(eval(sys.argv[1]))' "$cond" "$1"
    }
    mkdir -p "$t/esp/EFI/Boot"
    [[ $(copies "$t/esp/EFI") == True ]] || fail "GRUB not copied as the fallback with no Windows: $cond"
    mkdir -p "$t/esp/EFI/Microsoft/Boot" && : >"$t/esp/EFI/Microsoft/Boot/bootmgfw.efi"
    [[ $(copies "$t/esp/EFI") == False ]] || fail "GRUB copied over Windows' fallback loader: $cond"
fi
setup ""
echo '        if libcalamares.job.configuration.get("installEFIFallback"):' >"$b"
out=$(run) || fail "it failed with the step changed: $out"
grep -q "fallback loader left to CachyOS's step" <<<"$out" && grep -q 'installer configured' <<<"$out" ||
    fail "the step changed, not said, or not configured: $out"

# A file it edits gone (CachyOS moved it), after a note was said: the installer not started, and its last "AgrOS: "
# line, the one calamares-online.sh shows, says that, not the note
setup ""
printf '%s\n' '---' 'requirements:' '    requiredRam:        2.5' >"$t/c/modules/welcome_online.conf"
rm "$t/c/modules/bootloader.conf"
! out=$(run) || fail "a missing bootloader.conf not caught: $out"
[[ $(grep '^AgrOS: ' <<<"$out" | tail -1) == "AgrOS: a step of its own failed"* ]] || fail "the failure not its last line: $out"
echo "ok calamares-config"
