#!/usr/bin/env bash
# Boots the newest ISO in out/desktop/ in a VMware Workstation VM: puts it in the VM's DVD drive and starts it. The VM
# (AgrOS-test, ~/vmware/AgrOS-test; AGROS_VM=<.vmx> for another) is made the first time: UEFI, 4 CPUs, 8 GB of RAM,
# 3D, a 64 GB NVMe disk, a bridged network (VMware's NAT cut off downloads from CachyOS's CDN, so chwd failed to install).
# It boots its disk when something is installed there, the DVD otherwise (no fixed boot order: the firmware's own, as a
# PC's: after an install, the installed system comes up).
#   ./testiso.sh           the newest ISO, the VM as it is
#   ./testiso.sh --fresh   a new empty disk and boot entries first: a fresh install from the DVD
# Run it as yourself (no sudo). It won't touch a VM that's running: power it off first.
set -euo pipefail
src_dir=$(dirname "$(readlink -f "$0")")
vmx=$(realpath -m "${AGROS_VM:-$HOME/vmware/AgrOS-test/AgrOS-test.vmx}")  # (vmrun list gives full paths)
dir=${vmx%/*}
fresh=
case ${1:-} in
    --fresh) fresh=1 ;;
    "" | desktop) ;;  # (the old usage, the profile's name: desktop is the only one)
    *) echo "Usage: ./testiso.sh [--fresh]"; exit 1 ;;
esac
command -v vmrun >/dev/null || { echo "VMware Workstation isn't installed (vmrun not found)"; exit 1; }
iso=$(ls -t "$src_dir"/out/desktop/*.iso 2>/dev/null | head -1)
[[ -n $iso ]] || { echo "No ISO in out/desktop/: build one first (sudo ./buildiso.sh -p desktop -v -w)"; exit 1; }
if vmrun list | grep -qxF "$vmx"; then
    echo "The VM is running: power it off first (an install in it would be cut off)"
    exit 1
fi

if [[ ! -f $vmx ]]; then
    echo "Making the VM $vmx"
    mkdir -p "$dir"
    vmware-vdiskmanager -c -s 64GB -a lsilogic -t 0 "$dir/disk.vmdk" >/dev/null
    cat >"$vmx" <<VMX
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "21"
displayName = "AgrOS test"
guestOS = "other6xlinux-64"
firmware = "efi"
memsize = "8192"
numvcpus = "4"
mks.enable3d = "TRUE"
svga.graphicsMemoryKB = "8388608"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
vmci0.present = "TRUE"
nvme0.present = "TRUE"
nvme0:0.present = "TRUE"
nvme0:0.fileName = "disk.vmdk"
sata0.present = "TRUE"
sata0:1.present = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "$iso"
sata0:1.startConnected = "TRUE"
ethernet0.present = "TRUE"
ethernet0.connectionType = "bridged"
ethernet0.virtualDev = "vmxnet3"
ethernet0.addressType = "generated"
usb.present = "TRUE"
usb_xhci.present = "TRUE"
sound.present = "TRUE"
sound.virtualDev = "hdaudio"
sound.autoDetect = "TRUE"
tools.syncTime = "FALSE"
VMX
elif [[ -n $fresh ]]; then
    echo "A new empty disk, and the firmware's boot entries cleared"
    rm -f "$dir/disk.vmdk" "$dir/nvram"
    vmware-vdiskmanager -c -s 64GB -a lsilogic -t 0 "$dir/disk.vmdk" >/dev/null
fi

# The ISO in the DVD drive, connected at power-on
sed -i -e '/^sata0:1\.fileName = /d' -e '/^sata0:1\.startConnected = /d' "$vmx"
printf 'sata0:1.fileName = "%s"\nsata0:1.startConnected = "TRUE"\n' "$iso" >>"$vmx"
echo "Starting it with ${iso##*/}"
# (not with the editor's or Claude's variables: an Electron one left in made apps started from it misbehave)
env -u ELECTRON_RUN_AS_NODE vmrun -T ws start "$vmx" gui
