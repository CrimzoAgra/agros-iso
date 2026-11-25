#!/usr/bin/env bash
# .github/cachyos-sync.sh merge, on throwaway repos (CachyOS's, and this one's origin) with gh stubbed: main moved to the
# merge and the ISO started (waiting for AgrOS's CI, as a push); main moved on meanwhile, a pull request instead, of the
# branch "cachyos" as prepare pushed it (their master since moved on, and unreachable, changes nothing); a push refused
# for anything else (a rule, the network, the token), a failure, not a pull request saying main moved on
set -euo pipefail
# shellcheck source=lib.sh source-path=SCRIPTDIR
. "$(dirname "$0")/lib.sh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
unset GITHUB_OUTPUT
g() { git -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
# (gh: its calls written down, a pull request's text too; no pull request open. $t/gh-fails: that many "workflow run"
# requests fail first. sleep: no wait)
mkdir "$t/bin"
cat >"$t/bin/gh" <<'EOF'
#!/bin/sh
echo "$*" >>"$T/gh.log"
call="$1 $2"
while [ $# -gt 0 ]; do [ "$1" != --body-file ] || cat "$2" >>"$T/gh.log"; shift; done
n=$(cat "$T/gh-fails" 2>/dev/null || echo 0)
if [ "$call" = "workflow run" ] && [ "$n" -gt 0 ]; then echo $((n - 1)) >"$T/gh-fails"; exit 1; fi
exit 0
EOF
export T=$t
printf '#!/bin/sh\nexit 0\n' >"$t/bin/sleep"
chmod +x "$t/bin/gh" "$t/bin/sleep"
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
grep -q '^workflow run iso.yml --ref main -f wait=true$' "$t/gh.log" || fail "the ISO not asked to wait for AgrOS's CI: $(cat "$t/gh.log")"
# Its start refused twice by GitHub's API: started the third time. Three times: the run fails, said
echo 2 >"$t/gh-fails"
sync merge "$theirs"
((rc == 0)) && [[ $(grep -c '^workflow run iso.yml' "$t/gh.log") == 3 ]] ||
    fail "the ISO's start not tried again: rc $rc, $(cat "$t/gh.log")"
echo 3 >"$t/gh-fails"
sync merge "$theirs"
((rc != 0)) && grep -q "couldn't be started" <<<"$out" || fail "the ISO never started, not a failure: rc $rc, $out"
rm -f "$t/gh-fails"

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
# The branch as prepare pushes it, AgrOS's workflows on their master as a commit of its own: not counted nor listed as one
# of theirs
g -C "$t/up" checkout -q "$pushed" && g -C "$t/up" commit -q --allow-empty \
    -m "AgrOS's workflows on CachyOS's master (the sync: theirs are never pushed nor merged)" &&
    g -C "$t/up" push -q -f "$t/origin.git" HEAD:refs/heads/cachyos
sync pr "a look first"
grep -q 'CachyOS: 1 new commit' "$t/gh.log" && ! grep -q "AgrOS's workflows" "$t/gh.log" ||
    fail "AgrOS's commit on their master counted or listed as theirs: $(cat "$t/gh.log")"
echo "ok cachyos-sync"
