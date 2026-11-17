#!/usr/bin/env bash
# .github/cachyos-sync.sh merge, on throwaway repos (CachyOS's, and this one's origin) with gh stubbed: main moved to the
# merge and the ISO started; main moved on meanwhile, a pull request instead, of the branch "cachyos" as prepare pushed
# it (their master since moved on, and unreachable, changes nothing); a push refused for anything else (a rule, the
# network, the token), a failure, not a pull request saying main moved on
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
unset GITHUB_OUTPUT
g() { git -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
# (gh: its calls written down, a pull request's text too; no pull request open)
mkdir "$t/bin"
printf '#!/bin/sh\necho "$*" >>"%s/gh.log"\nwhile [ $# -gt 0 ]; do [ "$1" != --body-file ] || cat "$2" >>"%s/gh.log"; shift; done\n' \
    "$t" "$t" >"$t/bin/gh"
chmod +x "$t/bin/gh"
export PATH=$t/bin:$PATH

# CachyOS's repo, its master one commit ahead of what main has; origin, main at that base; a checkout of it
g init -q -b master "$t/up"
echo base >"$t/up/f" && g -C "$t/up" add f && g -C "$t/up" commit -qm base
g init -q --bare "$t/origin.git"
g -C "$t/up" push -q "$t/origin.git" HEAD:refs/heads/main
echo new >>"$t/up/f" && g -C "$t/up" commit -qam new
theirs=$(g -C "$t/up" rev-parse HEAD)
# (their master pushed as "cachyos", as prepare does; merge and pr read that, never CachyOS's repo, here unreachable)
g -C "$t/up" push -q "$t/origin.git" HEAD:refs/heads/cachyos
export CACHYOS_URL=$t/nowhere
# sync <args>: the script in a fresh checkout of origin, as the workflow's; its status in $rc, its output in $out
sync() {
    rm -rf "$t/w" "$t/gh.log"
    g clone -q "$t/origin.git" "$t/w"
    rc=0
    out=$(cd "$t/w" && bash "$here/.github/cachyos-sync.sh" "$@" 2>&1) || rc=$?
}

# A push refused (not because main moved on): fails, no pull request
printf '#!/bin/sh\necho "refused by a rule" >&2\nexit 1\n' >"$t/origin.git/hooks/pre-receive"
chmod +x "$t/origin.git/hooks/pre-receive"
sync merge "$theirs"
((rc != 0)) || fail "a refused push passed: $out"
! grep -q 'pr create\|pr edit' "$t/gh.log" 2>/dev/null || fail "a refused push opened a pull request: $(cat "$t/gh.log")"
rm "$t/origin.git/hooks/pre-receive"

# Pushed: main is the merge, the ISO started
sync merge "$theirs"
((rc == 0)) || fail "merge failed: $out"
[[ $(g -C "$t/origin.git" rev-parse main) == "$theirs" ]] || fail "main not moved to the merge"
grep -q '^workflow run iso.yml' "$t/gh.log" || fail "the ISO not started: $(cat "$t/gh.log")"

# Main moved on meanwhile: a pull request, said why, of what "cachyos" has (their master moved on again since: not in it)
echo more >>"$t/up/f" && g -C "$t/up" commit -qam more
g -C "$t/up" push -q -f "$t/origin.git" HEAD:refs/heads/cachyos
pushed=$(g -C "$t/up" rev-parse HEAD)
echo later >>"$t/up/f" && g -C "$t/up" commit -qam later
g clone -q "$t/origin.git" "$t/other"
echo agros >"$t/other/a" && g -C "$t/other" add a && g -C "$t/other" commit -qm agros && g -C "$t/other" push -q
sync merge "$pushed"
((rc == 0)) || fail "main moved on: failed ($out)"
grep -q '^pr create' "$t/gh.log" || fail "main moved on: no pull request ($(cat "$t/gh.log" 2>/dev/null))"
grep -q '^- [0-9a-f]* more$' "$t/gh.log" && ! grep -q ' later$' "$t/gh.log" && grep -q 'CachyOS: 1 new commit' "$t/gh.log" ||
    fail "the pull request's text not the branch cachyos's commits: $(cat "$t/gh.log")"
echo "ok cachyos-sync"
