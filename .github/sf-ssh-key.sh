#!/usr/bin/env bash
# SourceForge's SSH key (the SF_SSH_KEY secret) and its server's host key put in <ssh dir>, for upload-iso.sh: the ISO
# workflow's sourceforge job (~/.ssh) and its Upload step (/root/.ssh), so the host key is written in one place.
# Deleting the key afterwards is the caller's (the Upload step's trap).
#   SF_SSH_KEY=... .github/sf-ssh-key.sh <ssh dir>
set -euo pipefail
d=${1:?usage: sf-ssh-key.sh <ssh dir>}
[ -n "${SF_SSH_KEY:-}" ] || { echo "::error::Add the SF_SSH_KEY secret"; exit 1; }
install -d -m700 "$d"
printf '%s\n' "$SF_SSH_KEY" | install -m600 /dev/stdin "$d/id_ed25519"
# (SourceForge's published key, pinned: never taken on trust from the first connection)
echo 'frs.sourceforge.net ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQD35Ujalhh+JJkPvMckDlhu4dS7WH6NsOJ15iGCJLC' >"$d/known_hosts"
