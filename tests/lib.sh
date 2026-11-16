# shellcheck shell=bash
# Sourced first by every test: $here (the repo), $t (a throwaway folder, removed on exit) and fail
# shellcheck disable=SC2034  # (used by the tests that source this)
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
