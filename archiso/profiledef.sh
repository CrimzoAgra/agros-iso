#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="agros"
iso_label="AGROS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AgrOS <https://github.com/CrimzoAgra/agros>"
iso_application="AgrOS Live/Install (based on CachyOS)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
## GRUB
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# (zstd: much quicker to build than xz, and the live system unpacks it faster; the ISO a little bigger)
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/calamares-online.sh"]="0:0:755"
  ["/usr/local/bin/pkexec-wrapper"]="0:0:755"
  ["/usr/local/bin/agros-calamares-config"]="0:0:755"
  ["/usr/local/bin/live-session-menu"]="0:0:755"
)
