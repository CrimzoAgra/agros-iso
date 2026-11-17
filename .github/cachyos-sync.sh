#!/usr/bin/env bash
# The CachyOS sync (cachyos-sync.yml, daily): CachyOS's new commits merged into main by themselves when that's safe,
# else a pull request saying why not. In a checkout of this repo with origin/main; gh with GH_TOKEN.
#   cachyos-sync.sh prepare        their master fetched and pushed as the branch "cachyos". Nothing new: new=0. A merge
#                                  with no conflicts that keeps what AgrOS changed on purpose (none of the packages it
#                                  left out back, none of KDE's, its own installer) and changes only the harmless
#                                  files below (anything else a look comes first for): made, pushed as "cachyos-merge",
#                                  candidate=<its commit> (the workflow builds its ISO and runs the tests on
#                                  it, then merge); else why=<...>
#   cachyos-sync.sh merge <commit> main moved to that merge (only forward: main moved on since, a pull request
#                                  instead), the ISO started, the open pull request closed
#   cachyos-sync.sh pr <why>       the pull request from "cachyos" opened or brought up to date: their commits, the
#                                  files they change, those that conflict, and why it wasn't merged by itself
# Writes new=, candidate= and why= to $GITHUB_OUTPUT (or stdout). CACHYOS_URL: another CachyOS repo (the test's).
# merge and pr need origin/cachyos (the workflow's checkout fetches every branch)
set -euo pipefail
url=${CACHYOS_URL:-https://github.com/CachyOS/CachyOS-Live-ISO.git}
out=${GITHUB_OUTPUT:-/dev/stdout}
list=archiso/packages_desktop.x86_64
# The only files a change of theirs to merges by itself (prepare's why), as an extended regex on paths: docs, images,
# and the package list, which has its own checks. Anything else might run as root or decide what's trusted (the live
# user has sudo with no password, so its files count too), so a look comes first. An allowlist, as a list of the
# dangerous paths kept missing some
harmless='^((docs/|manual/)?[^/]+\.md|LICENSE|\.gitignore|.*\.(png|jpe?g)|archiso/packages_desktop\.x86_64)$'
# (merge and pr, hours later in the workflow: the branch "cachyos" prepare pushed, which the pull request shows and the
# merge was checked against. Their master fetched again could have moved on, the request's text then not its commits,
# and a failed fetch stopped a merge already checked)
case ${1:-} in
    prepare) git fetch -q "$url" master; theirs=$(git rev-parse FETCH_HEAD) ;;
    merge | pr) theirs=$(git rev-parse origin/cachyos) ;;
    *) echo "usage: cachyos-sync.sh prepare | merge <commit> | pr <why>" >&2; exit 2 ;;
esac
new=$(git rev-list --count "origin/main..$theirs")
# pkgs <commit>: its ISO's package list, one per line
pkgs() { git show "$1:$list" 2>/dev/null | sed 's/#.*//; s/[[:space:]]//g; /^$/d' | sort -u; }
# open_pr: the number of the open pull request from "cachyos" into main (none: empty)
open_pr() { gh pr list --head cachyos --base main --state open --json number -q '.[0].number'; }
# (git as the sync, its merge commits' author)
git_sync=(git -c user.name="AgrOS CachyOS sync" -c user.email="agros-sync@users.noreply.github.com")

# pr <why>: the pull request from "cachyos" opened, or brought up to date
pr() {
    local why=$1 conflicts tree body n title="CachyOS: $new new commit(s)"
    # (with conflicts: the merged tree's id, then the files that conflict)
    if tree=$(git merge-tree --write-tree --name-only --no-messages origin/main "$theirs"); then
        conflicts=
    else
        conflicts=$(tail -n +2 <<<"$tree")
    fi
    body=$(mktemp)
    {
        echo "CachyOS's ISO repo has $new commit(s) AgrOS doesn't have yet. **Not merged by itself:** $why."
        echo
        if [[ -n $conflicts ]]; then
            echo "**Conflicts with AgrOS's changes**, to resolve by hand"
            echo "(\`git fetch $url master && git merge FETCH_HEAD\`):"
            sed 's/.*/- `&`/' <<<"$conflicts"
            echo
        fi
        echo "**Commits:**"
        git log --format='- %h %s' "origin/main..$theirs"
        echo
        echo "**Files:**"
        echo '```'
        git diff --stat "origin/main...$theirs"
        echo '```'
    } >"$body"
    n=$(open_pr)
    if [[ -n $n ]]; then
        gh pr edit "$n" --title "$title" --body-file "$body"
    else
        gh pr create --head cachyos --base main --title "$title" --body-file "$body"
    fi
    rm -f "$body"
}

case ${1:-} in
    prepare)
        echo "new=$new" >>"$out"
        if [[ $new == 0 ]]; then echo "Nothing new from CachyOS"; exit 0; fi
        # (GitHub's token may not push a change to a workflow file: one of CachyOS's to theirs, .github/workflows, stops
        # the sync here each day until the branch is pushed by hand, said how)
        git push -q -f origin "$theirs:refs/heads/cachyos" || {
            echo "::error::The branch cachyos couldn't be pushed (a change of CachyOS's to .github/workflows, which GitHub's token may not push?). By hand: git fetch $url master && git push -f origin FETCH_HEAD:refs/heads/cachyos"
            exit 1
        }
        why=
        if ! git merge-tree --write-tree --no-messages origin/main "$theirs" >/dev/null; then
            why="it conflicts with AgrOS's changes"
        else
            "${git_sync[@]}" checkout -q --detach origin/main
            "${git_sync[@]}" merge -q --no-ff --no-edit -m "Merge CachyOS's master ($new commit(s)): checked by the CachyOS sync" "$theirs"
            # (what AgrOS left out of CachyOS's list on purpose: in it at the last merge, not in AgrOS's)
            base=$(git merge-base origin/main "$theirs")
            back=$(comm -12 <(comm -23 <(pkgs "$base") <(pkgs origin/main)) <(pkgs HEAD) | paste -sd' ')
            kde=$(pkgs HEAD | grep -E '^(plasma|kde|kf6|breeze)' | paste -sd' ' || true)
            # (what main would get of theirs besides the harmless files, looked at before it's published. A rename by
            # both its names: a file moved to a harmless name is a change to its old one too)
            touched=$(git diff --name-only --no-renames origin/main HEAD | { grep -vE "$harmless" || true; } | paste -sd' ')
            if [[ -n $back ]]; then
                why="it would bring back packages AgrOS left out: $back"
            elif [[ -n $kde ]]; then
                why="it would add KDE packages: $kde"
            elif ! grep -qx 'agros/calamares' <<<"$(pkgs HEAD)"; then
                why="AgrOS's own installer (agros/calamares) would leave the package list"
            elif [[ -n $touched ]]; then
                why="it changes files to look at first (not only docs, images or the package list): $touched"
            fi
        fi
        if [[ -n $why ]]; then
            echo "why=$why" >>"$out"
            pr "$why"
        else
            git push -q -f origin HEAD:refs/heads/cachyos-merge
            echo "candidate=$(git rev-parse HEAD)" >>"$out"
        fi
        ;;
    merge)
        commit=${2:?usage: cachyos-sync.sh merge <commit>}
        # (only forward: a push of main since, theirs kept, and this merge no longer on top of it)
        if git push -q origin "$commit:refs/heads/main"; then
            gh workflow run iso.yml --ref main
            n=$(open_pr)
            [[ -z $n ]] || gh pr close "$n" --comment "Merged by the CachyOS sync, its ISO built first: $commit"
            echo "Merged into main: $commit"
        else
            # (only when it did: a push refused for anything else, a rule, the network, the token, fails the run)
            git fetch -q origin main
            ! git merge-base --is-ancestor origin/main "$commit" || { echo "main couldn't be moved to $commit" >&2; exit 1; }
            pr "main moved on while its ISO was built"
        fi
        ;;
    pr) pr "${2:?usage: cachyos-sync.sh pr <why>}" ;;
esac
