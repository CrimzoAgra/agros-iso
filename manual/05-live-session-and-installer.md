# The live session and the installer

## The boot menu

The ISO boots with GRUB on UEFI and with syslinux on BIOS. Both menus say AgrOS, and the BIOS menu has the AgrOS
banner behind it.

On UEFI (GRUB, starts **AgrOS** after 10 seconds; the menu's first line is only the "Welcome to AgrOS" title):

- **AgrOS**: the live session on CachyOS's current kernel. The default.
- **AgrOS LTS Kernel**: the same on CachyOS's LTS kernel. Try it if the default doesn't boot.
- **AgrOS Legacy Hardware (GPU nomodeset)**: the LTS kernel with the graphics drivers' own modes off and NVIDIA's
  driver not loaded. For a screen that stays black.
- Memtest86+, the UEFI Shell, UEFI Firmware Settings, shut down and restart.

On BIOS (syslinux, starts the first entry after 15 seconds):

- **AgrOS default**: the live session on the LTS kernel.
- **AgrOS current kernel**: the same on CachyOS's current kernel, the UEFI menu's default.
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

## The installer

The installer opens by itself when the live session starts. If you close it, open it again with **Install AgrOS** in
the Super menu.

It's CachyOS's installer (Calamares) with AgrOS's look and settings:

- AgrOS's name, logo and colours, in the desktop's dark style with the Rubik font, pill buttons and rounded fields.
- The steps are pills along the bottom. Click one to go back to it, or forward as far as you've got.
- While it installs, the logo's leaves draw themselves as the loading animation.
- There's no page to pick a desktop: AgrOS is the desktop.
- It suggests a computer name starting with `agros-`, names the firmware's boot entry `AgrOS`, and sets up AgrOS's
  login screen on the new system.

It needs an internet connection, because it downloads the packages. If you aren't connected when it starts (on Wi-Fi,
at the first login), it says "Connect to the internet to install": connect, and it goes on by itself within a few
seconds. It waits up to 5 minutes; after that it stops with "The installer couldn't be set up", and you open it again
with **Install AgrOS**.

Next: [Troubleshooting](06-troubleshooting.md)
