# The live session and the installer

## The boot menu

The ISO boots with GRUB on UEFI and with syslinux on BIOS. Both menus say AgrOS, and the BIOS menu has the AgrOS
banner behind it.

On UEFI (GRUB, starts **AgrOS** after 10 seconds; the menu's first line is only the "Welcome to AgrOS" title):

- **AgrOS**: the live session on CachyOS's kernel. The default.
- **AgrOS Legacy Hardware (GPU nomodeset)**: the same with the graphics drivers' own modes off and NVIDIA's driver
  not loaded. For a screen that stays black.
- Memtest86+, UEFI Firmware Settings, shut down and restart.

On BIOS (syslinux, starts the first entry after 15 seconds):

- **AgrOS default**: the live session.
- **AgrOS Fallback (nomodeset)**: as the Legacy Hardware entry above.
- Boot existing OS, Memtest86+, Hardware Information (HDT), reboot and power off.

The live session's entries boot with no text on the screen (the kernel's and systemd's messages hidden, as on an
installed AgrOS). The Legacy Hardware and Fallback entries show it, so you can see where a boot stops.

## The live session

The live session is AgrOS's own desktop: Hyprland with the Caelestia shell and AgrOS's settings. greetd logs the live
user (`liveuser`) straight in. If you log out, you get a text login that starts the desktop again.

It's cut down to what installing needs:

- The Super menu lists only the installer (**Install AgrOS**), a terminal (foot), the file manager (Thunar), the
  browser (LibreWolf) and the partition editor (GParted).
- The dock has no pinned apps. The installer's window shows in it with AgrOS's logo.
- The big apps of `agros-desktop` aren't on the ISO. They're only installed on the new system.
- It never sleeps, so a long install can't stop halfway: the screen still goes off when idle (any key brings it
  back), but there's no suspend, from the idle timer, the lid or the session menu.

## The installer

The installer opens by itself when the live session starts: a splash with the AgrOS logo shows while it gets ready (it
takes a minute or two). If you close it, open it again with **Install AgrOS** in the Super menu; while it's open, that
brings its window forward.

It's CachyOS's installer (Calamares) with AgrOS's look and settings:

- AgrOS's name, logo and colours, in the desktop's dark style with the Rubik font, pill buttons and rounded fields.
- The steps are pills along the bottom. Click one to go back to it, or forward as far as you've got.
- While it installs, the logo's leaves draw themselves as the loading animation.
- There's no page to pick a desktop: AgrOS is the desktop.
- It suggests a computer name starting with `agros-`, names the firmware's boot entry `AgrOS`, and sets up AgrOS's
  login screen on the new system.
- It installs GRUB, with no page to pick another boot loader: AgrOS's boot menu, its look and the snapshots in it
  are GRUB's.
- It needs 20 GB for AgrOS. Beside Windows (**Install alongside**, or **Replace a partition** on free space), it uses
  the EFI partition Windows already has, even Windows' own 100 MB one, and leaves Windows' fallback boot file
  (`EFI/Boot/bootx64.efi`) as it is. Getting Windows ready first (Fast Startup,
  BitLocker) is in AgrOS's manual:
  [Keeping Windows](https://github.com/CrimzoAgra/agros/blob/main/manual/02-installing.md#keeping-windows).
- If Hyprland was updated after the ISO was made and AgrOS hasn't checked the new version yet, the new system gets
  the ISO's own Hyprland instead, when it still fits with the rest; it updates once AgrOS has checked the new one.
  `/var/log/agros-gate-install.log` on the new system says which.
- The keyboard layout you pick on its keyboard page applies to the live session at once, so the password you type on
  the users page is the one your new system's layout types at its login screen.

It needs an internet connection, because it downloads the packages. If you aren't connected when it starts (on Wi-Fi,
at the first login), it says "Connect to the internet to install": connect, and it goes on by itself within a few
seconds. It waits up to 5 minutes; after that it stops with "The installer couldn't be set up", and you open it again
with **Install AgrOS**.

Next: [Troubleshooting](06-troubleshooting.md)
