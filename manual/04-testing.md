# Testing it in a VM

`testiso.sh` boots the newest ISO in `out/desktop/` in a VMware Workstation VM. Install VMware Workstation first, then
run it as yourself (no sudo):

```bash
./testiso.sh           # the newest ISO, the VM as it is
./testiso.sh --fresh   # a new empty disk first: a fresh install from the ISO
```

The first time, it creates a VM called `AgrOS test` in `~/vmware/AgrOS-test` (`AGROS_VM=<file>.vmx` for another): UEFI
firmware, 4 CPUs, 8 GB of RAM, 3D acceleration, a 64 GB NVMe disk and a bridged network. Bridged, not NAT: VMware's NAT
cut off downloads from CachyOS's mirror, and the installer's hardware detection (chwd) failed. After that it reuses
the same VM. Each run puts the newest ISO in the VM's DVD drive and starts it.

There's no fixed boot order: the VM boots its disk when something is installed there, and the ISO otherwise, as a PC
does. So after an install, restarting brings up the installed system. To install again, use `--fresh`, or pick the DVD
in the VM's boot menu (Esc as it starts). The script won't touch a VM that's running: power it off first.

The VM has a network connection, so you can run the installer all the way through. The VM's disk is wiped by
**Erase disk**, which is fine: nothing else is on it.

Next: [The live session and the installer](05-live-session-and-installer.md)
