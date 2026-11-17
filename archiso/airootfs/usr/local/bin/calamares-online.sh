#!/bin/bash

# AgrOS: notifications through agros-scripts' notify-when-up, in the background: at login the notification server
# (Caelestia, no D-Bus activation) may not be up yet, and it tries again for up to a minute. (9>&-: not holding the lock)
notify() { /usr/lib/agros/bin/notify-when-up "$@" >/dev/null 2>&1 9>&- & }
# AgrOS: online as the install needs it (NetworkManager's own check: full connectivity); offline, what to do said
online() { [[ $(nmcli networking connectivity check 2>/dev/null) == full ]]; }
notify_offline() { notify -a AgrOS -i network-wireless "Connect to the internet to install" "The installer opens once you're connected."; }
# AgrOS: a splash while it gets ready (online, the clock, the package keys: a minute or two before its window opens,
# where nothing showed), its line of text from the status file; closed once the installer's window is up, or when this
# stops (the installer not set up: said in a notification). No XDG_RUNTIME_DIR, no splash: a fixed name in the shared
# /tmp could be planted or watched by another account
splash_file=${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/agros-installer-splash}
splash() { [[ -z $splash_file ]] || printf '%s\n' "$1" >"$splash_file"; }
# (drawn on the CPU, set here on any machine rather than left to the desktop's VMware fallback: on VMware's GPU without
# the shim, Hyprland refuses a GPU-drawn window and it closed at once, never seen. A logo and a spinner need no GPU)
# splash_show: the splash opened, unless one is up. The splash itself holds its lock (taken before it starts, so two
# starts at once can't both open one), and its pid is in a file: a second start of this reopens one the user closed,
# and the first run closes whichever is up
splash_show() {
    [[ -n $splash_file ]] || return 0
    (
        flock -n 8 || exit 0
        echo "$BASHPID" >"$splash_file.pid"
        LIBGL_ALWAYS_SOFTWARE=1 exec qs -p /usr/share/agros/installer-splash/shell.qml >/dev/null 2>&1 9>&-
    ) 8>"$splash_file.lock" &
}
# (a pid only killed while the lock is held: one the user closed left a stale pid, which may be another process's now)
splash_close() { [[ -n $splash_file ]] && ! flock -n "$splash_file.lock" true && kill "$(cat "$splash_file.pid")" 2>/dev/null; }
splash_open() {
    [[ -n $splash_file ]] || return 0
    splash "$1"
    splash_show
    trap splash_close EXIT
}
# The installer's window up (Hyprland's list of windows)
shown() { hyprctl -j clients 2>/dev/null | jq -e 'any(.[]; .class == "io.calamares.calamares")' >/dev/null; }

# AgrOS: the installer not started, said in a notification (its one way of failing, before anything touched the disks)
not_set_up() {
    notify -u critical -a AgrOS -i dialog-error "The installer couldn't be set up" "$1 Nothing was changed on your disks.${2:+ $2}"
    exit 1
}

main() {
    # AgrOS: one at a time. Started again (from the menu, while the one the session opened is still starting or open),
    # it starts no second one (two reset the keyring under each other): it brings the open installer forward, waits for
    # its window, or (offline) says again to connect. The lock is held until the installer closes
    # (no XDG_RUNTIME_DIR: in the user's home, not the shared /tmp, where another account could plant or hold it)
    exec 9>"${XDG_RUNTIME_DIR:-$HOME}/.calamares-online.lock"
    if ! flock -n 9; then
        # (open: brought forward, from whichever workspace it's on, by the desktop's own focus (dots.focus_window:
        # raised over other floating windows too, as a focus alone leaves it under them). Its process there but no
        # window yet, opening or closing: waited for, up to 30 s, its window (brought forward) or its end (a new one
        # started, as asked). Still getting ready: offline, what to do said again; else its splash shown again, if the
        # user closed it, as nothing else shows until the installer's window opens)
        forward() {
            hyprctl eval 'local w = hl.get_window("class:io.calamares.calamares"); if w and dots and dots.focus_window then dots.focus_window(w.address) end' >/dev/null 2>&1
        }
        if shown; then
            forward; exit 0
        elif pgrep -x calamares >/dev/null; then
            for _ in {1..30}; do
                sleep 1
                if shown; then forward; exit 0; fi
                flock -n 9 && break
            done
            # (30 s and still no window, nor its end: a slow machine)
            flock -n 9 || { splash_show; exit 0; }
        elif ! online; then
            notify_offline
            exit 0
        else
            splash_show
            exit 0
        fi
    fi
    # AgrOS: the desktop first: the splash and the installer wait for Caelestia's bar to be up (its IPC answering; up to
    # 20 s), not on a bare screen before it
    for _ in {1..100}; do qs ipc -c caelestia show >/dev/null 2>&1 && break; sleep 0.2; done
    if online; then splash_open "Getting the installer ready…"; else splash_open "Connect to the internet to install: the installer opens once you're connected (Wi-Fi in the bar)."; fi
    # Online first: it opens at login, before a Wi-Fi user could connect, and the clock and keys below come from the
    # internet. Not connected: said once, then checked every 2 s for up to 5 minutes (the keyring step below fails
    # only after that, with its own notification)
    if ! online; then
        notify_offline
        for _ in {1..150}; do
            sleep 2
            online && break
        done
    fi
    # AgrOS: up to a minute or two of setup (the clock, the package keys) before its window opens: said, or it looked
    # like it never started (once connected: offline, the two came at once; still offline after the wait, the keyring
    # step's own notification says it couldn't be set up)
    online && splash "Getting the installer ready…"

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
    # shellcheck disable=SC2024  # (the log is the user's own: written as them, not root)
    if ! sudo /usr/local/bin/agros-calamares-config >>"$log" 2>&1; then
        why=$(grep '^AgrOS:' "$log" | tail -1)
        not_set_up "${why:-The AgrOS settings for the installer did not apply}." "Details: $log"
    fi
    # (the splash closed once its window is up: up to 2 minutes looked for)
    { for _ in {1..240}; do shown && break; sleep 0.5; done; splash_close; } 9>&- &
    # (not exec: pkexec closes the lock, and this keeps it while the installer is open)
    pkexec-wrapper calamares -D6 >> "$log"
}

main "$@"
