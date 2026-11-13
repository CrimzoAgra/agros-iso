#!/bin/bash
# Publishing is automatic (publish/install.sh, once): a new ISO after each change on GitHub. This publishes now
# instead of at the next check, also a commit that failed (normally tried again after 6 hours), and shows its log.
set -euo pipefail
sudo rm -f /var/lib/agros-iso-publish/failed
sudo systemctl start --no-block agros-iso-publish.service
exec journalctl -fu agros-iso-publish
