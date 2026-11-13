#!/usr/bin/env bash
# Publishes the ISO for a commit of agros-iso: waits for it to be on GitHub's main, builds the ISO from exactly that
# commit (a clean copy in ~/.cache/agros-iso-publish, so what you change meanwhile isn't in it) and uploads it to
# SourceForge (upload-iso.sh, its settings in ~/.config/agros-iso/upload.conf). The push hook (.githooks/pre-push) runs
# it in a terminal window of its own after each push of main; by hand:
#   ./publish-iso.sh            the newest commit on GitHub's main
#   ./publish-iso.sh <commit>   that one, once it's on GitHub's main
# AGROS_NO_PUBLISH=1 git push: a push that doesn't publish.
set -euo pipefail
src_dir=$(dirname "$(readlink -f "$0")")
clone=${XDG_CACHE_HOME:-$HOME/.cache}/agros-iso-publish
die() { echo "publish-iso: $*" >&2; exit 1; }

# One at a time: a push while one builds waits for it, then publishes its own commit
mkdir -p "${clone%/*}"
exec 8>"$clone.lock"
flock -n 8 || { echo "Another ISO is being published: this one waits for it"; flock 8; }

# The upload's settings and SSH key, before 30 minutes of building
"$src_dir/upload-iso.sh" --check

# What's on GitHub (what the installer also reads, netinstall.yaml from main): the commit pushed, once it's there
remote_main() { git -C "$src_dir" ls-remote origin refs/heads/main | cut -f1; }
commit=${1:-$(remote_main)}
[[ -n $commit ]] || die "can't read GitHub's main (offline?)"
for _ in $(seq 60); do
    [[ $(remote_main) == "$commit" ]] && break
    sleep 5
done
[[ $(remote_main) == "$commit" ]] || die "${commit:0:7} isn't GitHub's main after 5 minutes (the push failed, or main moved on): not published"

# The clean copy, at that commit (fetched from this repo: it has it)
[[ -d $clone/.git ]] || git clone -q --no-checkout "$src_dir" "$clone"
git -C "$clone" fetch -q "$src_dir" "$commit"
git -C "$clone" checkout -q --force --detach "$commit"
git -C "$clone" clean -q -fdx -e out -e build
echo "Building the ISO for ${commit:0:7}: $(git -C "$clone" log -1 --format=%s "$commit")"

# The ISOs of earlier publishes go (3.7 GB each: they're on SourceForge); root's, from the build
echo "Your password, for the build (it runs as root):"
sudo rm -rf "$clone/out"
sudo "$clone/buildiso.sh" -p desktop -v -w -u
echo "Published ${commit:0:7} ($(date '+%F %T'))."
