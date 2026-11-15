#!/usr/bin/env bash
# CachyOS's new commits as a pull request into main (cachyos-sync.yml, daily): their master pushed as the branch
# "cachyos", and one pull request from it, opened or brought up to date, listing their commits, the files they change
# and those that conflict with AgrOS's. Never merged here. Nothing new: nothing done (a pull request merged by then
# closed itself). In a checkout of this repo with origin/main; CACHYOS_URL: another CachyOS repo (the test's)
set -euo pipefail
url=${CACHYOS_URL:-https://github.com/CachyOS/CachyOS-Live-ISO.git}
git fetch -q "$url" master
theirs=$(git rev-parse FETCH_HEAD)
new=$(git rev-list --count "origin/main..$theirs")
if [[ $new == 0 ]]; then
    echo "Nothing new from CachyOS"
    exit 0
fi
git push -q -f origin "$theirs:refs/heads/cachyos"
# (merge-tree: the merge worked out without touching a work tree; its first line the result, then the files in conflict)
if out=$(git merge-tree --write-tree --name-only --no-messages origin/main "$theirs"); then
    conflicts=
else
    conflicts=$(tail -n +2 <<<"$out")
fi
body=$(mktemp)
{
    echo "CachyOS's ISO repo has $new commit(s) AgrOS doesn't have yet. Read each one before merging: one that merges"
    echo "cleanly can still bring back something AgrOS left out on purpose (KDE's apps, their installer from staging)."
    echo
    if [[ -n $conflicts ]]; then
        echo "**Conflicts with AgrOS's changes**, to resolve by hand"
        echo "(\`git fetch $url master && git merge FETCH_HEAD\`):"
        sed 's/.*/- `&`/' <<<"$conflicts"
    else
        echo "No conflicts with AgrOS's changes."
    fi
    echo
    echo "**Commits:**"
    git log --format='- %h %s' "origin/main..$theirs"
    echo
    echo "**Files:**"
    echo '```'
    git diff --stat "origin/main...$theirs"
    echo '```'
} >"$body"
title="CachyOS: $new new commit(s)"
n=$(gh pr list --head cachyos --base main --state open --json number -q '.[0].number')
if [[ -n $n ]]; then
    gh pr edit "$n" --title "$title" --body-file "$body"
else
    gh pr create --head cachyos --base main --title "$title" --body-file "$body"
fi
rm -f "$body"
