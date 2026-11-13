#!/bin/bash
# Sets up automatic publishing on this PC, once: sudo ./publish/install.sh (again after changing the files here).
# A copy owned by root (yours, here, can be edited without a password: not what root runs) and a timer that runs it.
set -euo pipefail
[[ $EUID -eq 0 && -n ${SUDO_USER:-} ]] || { echo "Run it with sudo: sudo $0" >&2; exit 1; }
here=$(dirname "$(readlink -f "$0")")
install -Dm755 "$here/agros-iso-publish" /usr/local/lib/agros-iso-publish/agros-iso-publish
sed "s/@USER@/$SUDO_USER/" "$here/agros-iso-publish.service" >/etc/systemd/system/agros-iso-publish.service
install -m644 "$here/agros-iso-publish.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now agros-iso-publish.timer
echo "Publishing is automatic: a new ISO after each change on GitHub (agros-iso's main, or AgrOS's packages once CI passed)."
