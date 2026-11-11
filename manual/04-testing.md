# Testing it in a VM

`testiso.sh` boots the ISO you built in a VirtualBox VM. Install VirtualBox first, then run it as yourself (no sudo)
with the profile's name:

```bash
./testiso.sh desktop
```

The first time, it creates a VM called `CachyOS` in `~/VirtualBox VMs/CachyOS`: UEFI firmware, 4 CPUs, 7 GB of RAM,
3D acceleration, a NAT network and a 10 GB virtual disk. After that it reuses the same VM. Each run puts the ISO from
`out/desktop/` in the VM's DVD drive and starts it.

Keep a single ISO in `out/desktop/`. With more than one, the script stops with "No ISO to load present".

The VM has a network connection, so you can run the installer all the way through. The VM's disk is wiped by
**Erase disk**, which is fine: nothing else is on it.

Next: [The live session and the installer](05-live-session-and-installer.md)
