#!/usr/bin/env bash
# cachyos-sync.yml's last step, which picks what the sync does from the package check's, the ISO check's and the
# tests' results: merged when the packages passed, the ISO built and the tests passed; a pull request otherwise, saying
# why: what the package check found (a package that starts something by itself, one AgrOS relies on gone), the package
# check failing (it couldn't tell: never read as nothing found), the tests, a wait for AgrOS's check (the ISO job ran
# and its gate held it), or the ISO not built (it failed, or its job never ran: not a wait). The step's own commands,
# read from the workflow, with the sync's script stubbed
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
# (the merge job's run block, the workflow's last, as GitHub runs it: its indentation taken off)
awk '/^      - name: Into main, or a pull request$/ { job = 1 } job && /^        run: \|$/ { on = 1; next }
    on { sub(/^          /, ""); print }' "$here/.github/workflows/cachyos-sync.yml" | tr -d '\r' >"$t/step.sh"
grep -q 'cachyos-sync.sh merge' "$t/step.sh" || fail "the merge step's commands not found in cachyos-sync.yml"
mkdir -p "$t/w/.github"
printf '#!/bin/sh\necho "$*"\n' >"$t/w/.github/cachyos-sync.sh"
chmod +x "$t/w/.github/cachyos-sync.sh"
# step <tests> <check> <built> [<package check> [<what it found>]]: what the step had the sync do
step() {
    (cd "$t/w" && TESTS=$1 CHECK=$2 BUILT=$3 PACKAGES=${4:-success} HELD=${5:-} CANDIDATE=abc RUN_URL=url \
        bash "$t/step.sh")
}

[[ $(step success success true) == "merge abc" ]] || fail "built and tested: not merged ($(step success success true))"
[[ $(step failure success true) == "pr its tests fail (url)" ]] || fail "tests failing: $(step failure success true)"
[[ $(step success success false) == "pr its ISO waits for AgrOS's check"* ]] ||
    fail "held by the gate: not said as a wait ($(step success success false))"
[[ $(step success success "") == "pr its ISO wasn't built (url)" ]] ||
    fail "the ISO job skipped: said as $(step success success "")"
[[ $(step success failure "") == "pr its ISO wasn't built (url)" ]] ||
    fail "the ISO failed: said as $(step success failure "")"
# The package check found something: a pull request saying what, the ISO check skipped (not "wasn't built")
found="it adds packages that start things by themselves: x (y)"
[[ $(step success skipped "" success "$found") == "pr $found" ]] ||
    fail "the package check's finding not said: $(step success skipped "" success "$found")"
# It failed (a repo unreachable): a pull request, never a merge, even with the ISO built and the tests passed
[[ $(step success success true failure) == "pr its packages couldn't be checked (url; tried again tomorrow)" ]] ||
    fail "the package check failing: $(step success success true failure)"
[[ $(step success skipped "" failure) == "pr its packages couldn't be checked"* ]] ||
    fail "the package check failing, the ISO skipped: $(step success skipped "" failure)"
echo "ok cachyos-sync-step"
