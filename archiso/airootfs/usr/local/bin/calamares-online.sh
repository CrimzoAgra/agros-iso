#!/bin/bash

# AgrOS: notifications through agros-scripts' notify-when-up, in the background: at login the notification server
# (Caelestia, no D-Bus activation) may not be up yet, and it tries again for up to a minute. (9>&-: not holding the lock)
notify() { /usr/lib/agros/bin/notify-when-up "$@" >/dev/null 2>&1 9>&- & }

# AgrOS: the installer not started, said in a notification (its one way of failing, before anything touched the disks)
not_set_up() {
    notify -u critical -a AgrOS -i dialog-error "The installer couldn't be set up" "$1 Nothing was changed on your disks.${2:+ $2}"
    exit 1
}

main() {
    # AgrOS: one at a time. Started again (from the menu, while the one the session opened is still starting or open),
    # it just stops: two reset the keyring under each other. The lock is held until the installer closes
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/calamares-online.lock"
    flock -n 9 || exit 0

    # Online first: it opens at login, before a Wi-Fi user could connect, and the clock and keys below come from the
    # internet. Not connected: said once, then checked every 2 s for up to 5 minutes (the keyring step below fails
    # only after that, with its own notification)
    online() { [[ $(nmcli networking connectivity check 2>/dev/null) == full ]]; }
    if ! online; then
        notify -a AgrOS -i network-wireless "Connect to the internet to install" \
            "The installer opens once you're connected."
        for _ in {1..150}; do
            sleep 2
            online && break
        done
    fi

    # The clock synced first (bounded: no NTP server reached in 30 s, it goes on): with a wrong clock the keys read as
    # "created in the future", and the keyring checks below fail
    timedatectl set-ntp true
    for _ in {1..30}; do
        [[ $(timedatectl show -p NTPSynchronized --value) == yes ]] && break
        sleep 1
    done
    # A fresh keyring, made and populated before pacman needs it (AgrOS: it was installing the keyrings with an empty one).
    # The ISO's pacman-init.service makes one at boot: waited for (start blocks until the oneshot is done), or it was
    # still writing to the keyring this deletes. Only waited for: its keyring is made again here anyway.
    # (what is in /etc/pacman.d/gnupg goes, not the folder itself, kept with its owner and mode)
    sudo systemctl start pacman-init.service || :
    # Then the latest archlinux-keyring and cachyos-keyring: Arch often signs its keyring with a newly made key, and an
    # older keyring on the ISO failed the install; also when the installer ranks the mirrors and gets a "faulty" one
    # (their install scripts add their new keys to the keyring). Any of it failing stops here, as a bad config does:
    # with no keys, the install would fail after the disk was wiped
    if ! { sudo find /etc/pacman.d/gnupg -mindepth 1 -delete &&
        sudo pacman-key --init &&
        sudo pacman-key --populate archlinux cachyos agros &&
        sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring; }; then
        not_set_up "The package keys couldn't be set up: is the internet connected?"
    fi

    local progname log
    progname="$(basename "$0")"
    log="/home/liveuser/cachy-install.log"

    local SYSTEM=""

    if [ -d /sys/firmware/efi ]; then
        SYSTEM="UEFI SYSTEM"
    else
        SYSTEM="BIOS/MBR SYSTEM"
    fi

    local ISO_VERSION
    ISO_VERSION="$(cat /etc/version-tag)"
    echo "USING ISO VERSION: ${ISO_VERSION}"

    # (The ISO's own installer, AgrOS's rebuild: not installed again here from [agros], a partial upgrade that could
    # bring one built against newer libraries than the ISO's. A new one comes with a new ISO, built after each
    # change to what goes into it)

    # Get Hardware Informations
    inxi -F > "$log"

    cat <<EOF >> "$log"
########## $log by $progname
########## Started (UTC): $(date -u "+%x %X")
########## ISO version: $ISO_VERSION
########## System: $SYSTEM
EOF

    sudo cp "/usr/share/calamares/settings_online.conf" /etc/calamares/settings.conf
    # AgrOS: its package list (the AgrOS desktop), no desktop page, its login screen kept
    # (not started when a setting didn't apply: a CachyOS update had moved it, and the install would have gone on with
    # CachyOS's, Limine and no bootloader among them, failing only after the disk was wiped)
    if ! sudo /usr/local/bin/agros-calamares-config >>"$log" 2>&1; then
        why=$(grep '^AgrOS:' "$log" | tail -1)
        not_set_up "${why:-The AgrOS settings for the installer did not apply}." "Details: $log"
    fi
    # (not exec: pkexec closes the lock, and this keeps it while the installer is open)
    pkexec-wrapper calamares -D6 >> "$log"
}

main "$@"
