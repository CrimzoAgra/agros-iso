#!/usr/bin/env bash
# Every test, each in a throwaway folder (nothing built, nothing of the repo's changed): tests/run.sh, or
# tests/run.sh <name>... One line each, "ok <test>" or "FAIL <test>: <why>"; a failure fails the run
here=$(cd "$(dirname "$0")" && pwd)
failed=0
tests=("$@")
if ((!${#tests[@]})); then
    for f in "$here"/*.sh; do f=${f##*/}; [[ $f == run.sh || $f == lib.sh ]] || tests+=("${f%.sh}"); done
fi
for t in "${tests[@]}"; do
    if out=$(bash "$here/$t.sh" 2>&1 </dev/null); then
        echo "${out##*$'\n'}"
    else
        f=$(grep -m1 '^FAIL: ' <<<"$out") || f=${out##*$'\n'}
        echo "FAIL $t: ${f#FAIL: }"
        failed=1
    fi
done
exit $failed
