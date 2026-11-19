#!/usr/bin/env bash
# The workflows' checkouts take the run's own commit (github.sha), or the one the CachyOS sync passes (inputs.ref),
# never a branch by name (github.ref, "refs/heads/main"): actions/checkout fetches a named branch's tip as it is when
# the step runs, so an ISO run that waited its turn, or was re-run days later, built a newer commit than its own while
# its publish job (checked out at its own) signed and uploaded it with that commit's scripts
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
bad=$(grep -n '^ *ref: .*github\.ref\b' "$here"/.github/workflows/*.yml | tr -d '\r' || true)
[[ -z $bad ]] || fail "a checkout of a branch's tip, not the run's commit: $bad"
for f in iso.yml tests.yml; do
    grep -q '^ *ref: \${{ inputs\.ref || github\.sha }}' "$here/.github/workflows/$f" ||
        fail "$f's checkout not at inputs.ref or the run's commit"
done
echo "ok workflow-checkout"
