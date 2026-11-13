#!/bin/bash

main() {
    # Remove current keyring first, to complete initiate it
    sudo rm -rf /etc/pacman.d/gnupg
    # We are using this, because archlinux is signing the keyring often with a newly created keyring
    # This results into a failed installation for the user.
    # Installing archlinux-keyring fails due not being correctly signed
    # Mitigate this by installing the latest archlinux-keyring on the ISO, before starting the installation
    # The issue could also happen, when the installation does rank the mirrors and then a "faulty" mirror gets used
    sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
    # Also populate the keys, before starting the Installer, to avoid above issue
    sudo pacman-key --init
    sudo pacman-key --populate archlinux cachyos agros
    # Also use timedatectl to sync the time with the hardware clock
    # There has been a bunch of reports, that the keyring was created in the future
    # Syncing appears to fix it
    timedatectl set-ntp true

    local progname="$(basename "$0")"
    local log="/home/liveuser/cachy-install.log"
    local mode="online"  # TODO: keep this line for now

    local SYSTEM=""

    if [ -d /sys/firmware/efi ]; then
        SYSTEM="UEFI SYSTEM"
    else
        SYSTEM="BIOS/MBR SYSTEM"
    fi

    local ISO_VERSION="$(cat /etc/version-tag)"
    echo "USING ISO VERSION: ${ISO_VERSION}"

    # (AgrOS's rebuild of the installer: CachyOS's own can lag behind an Arch library update and not start)
    sudo pacman -Sy --noconfirm agros/cachyos-calamares-next

    # Get Hardware Informations
    inxi -F > "$log"

    cat <<EOF >> "$log"
########## $log by $progname
########## Started (UTC): $(date -u "+%x %X")
########## ISO version: $ISO_VERSION
########## System: $SYSTEM
EOF

    sudo cp "/usr/share/calamares/settings_${mode}.conf" /etc/calamares/settings.conf
    # AgrOS: its package list (the AgrOS desktop), no desktop page, its login screen kept
    # (not started when a setting didn't apply: a CachyOS update had moved it, and the install would have gone on with
    # CachyOS's, Limine and no bootloader among them, failing only after the disk was wiped)
    if ! sudo /usr/local/bin/agros-calamares-config >>"$log" 2>&1; then
        why=$(grep '^AgrOS:' "$log" | tail -1)
        notify-send -u critical -a AgrOS -i dialog-error "The installer couldn't be set up" \
            "${why:-The AgrOS settings for the installer did not apply}. Nothing was changed on your disks. Details: $log"
        exit 1
    fi
    exec pkexec-wrapper calamares -D6 >> $log
}

main "$@"
