#!/bin/bash
#
# Uploads a built ISO, with its .sha256, .sig and .pkgs.txt, to SourceForge's file release system.
#
#   ./upload-iso.sh [--dry-run] [iso]
#
# Without an ISO it takes the newest in out/desktop. Settings come from the environment or from
# ~/.config/agros-iso/upload.conf (the environment wins):
#   SF_USER     SourceForge user name (its SSH key must be in the account's settings)
#   SF_PROJECT  SourceForge project (the short name in https://sourceforge.net/projects/<project>)
#   SF_FOLDER   folder in the project's Files [default: iso]
#   SF_API_KEY  optional: makes the uploaded ISO the project's default download

set -euo pipefail

die() { echo "upload-iso: $*" >&2; exit 1; }

# Run with sudo (buildiso.sh -u): upload as the user who ran it, with their SSH key, gpg keyring and config
if [[ $EUID -eq 0 && -n ${SUDO_USER:-} ]]; then
    exec sudo -u "$SUDO_USER" -H "$0" "$@"
fi

dry_run=false
iso=
for arg in "$@"; do
    case $arg in
        -n|--dry-run) dry_run=true ;;
        -h|--help) sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option $arg" ;;
        *) [[ -z $iso ]] || die "only one ISO at a time"; iso=$arg ;;
    esac
done

# The config file is the user's own, sourced as them; the environment's values win over it
conf=${XDG_CONFIG_HOME:-$HOME/.config}/agros-iso/upload.conf
env_user=${SF_USER:-} env_project=${SF_PROJECT:-} env_folder=${SF_FOLDER:-} env_key=${SF_API_KEY:-}
# shellcheck source=/dev/null
[[ -r $conf ]] && source "$conf"
SF_USER=${env_user:-${SF_USER:-}}
SF_PROJECT=${env_project:-${SF_PROJECT:-}}
SF_FOLDER=${env_folder:-${SF_FOLDER:-iso}}
SF_API_KEY=${env_key:-${SF_API_KEY:-}}
SF_FOLDER=${SF_FOLDER#/}; SF_FOLDER=${SF_FOLDER%/}
[[ -n $SF_USER ]] || die "SF_USER isn't set: put SF_USER=<your SourceForge user> in $conf (or the environment)"
[[ -n $SF_PROJECT ]] || die "SF_PROJECT isn't set: put SF_PROJECT=<project> in $conf (or the environment)"
[[ -n $SF_FOLDER ]] || die "SF_FOLDER is empty"

if [[ -z $iso ]]; then
    out=$(dirname "$(readlink -f "$0")")/out/desktop
    iso=$(ls -t "$out"/*.iso 2>/dev/null | head -n1) || true
    [[ -n $iso ]] || die "no ISO in $out (build one, or give its path)"
fi
[[ -f $iso && $iso == *.iso ]] || die "$iso isn't an ISO file"
iso=$(readlink -f "$iso")
dir=${iso%/*} name=${iso##*/}

# Refuse an ISO whose checksum or signature doesn't check out
[[ -f $iso.sha256 ]] || die "$name.sha256 is missing"
echo "Checking $name.sha256..."
(cd "$dir" && sha256sum --quiet -c "$name.sha256") || die "$name doesn't match its .sha256"
if [[ -f $iso.sig ]]; then
    echo "Checking $name.sig..."
    if ! gpg_out=$(gpg --batch --verify "$iso.sig" "$iso" 2>&1); then
        echo "$gpg_out" >&2
        die "$name.sig doesn't verify for $USER (bad signature, or the signing key isn't in their keyring)"
    fi
    echo "$gpg_out" | grep -E 'Good signature|using' | sed 's/^/  /' || true
else
    echo "Warning: no $name.sig, the ISO goes up unsigned" >&2
fi

files=("$iso")
for f in "$iso.sha256" "$iso.sig" "${iso%.iso}.pkgs.txt"; do
    [[ -f $f ]] && files+=("$f")
done

dest="$SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PROJECT/$SF_FOLDER/"
url="https://sourceforge.net/projects/$SF_PROJECT/files/$SF_FOLDER/$name"
if command -v rsync >/dev/null; then
    # rsync creates the last folder of the path; --partial lets a stopped upload resume
    cmd=(rsync -e ssh --partial --progress --chmod=F644 "${files[@]}" "$dest")
else
    # shortcut: scp doesn't create the folder, it must exist in the project's Files; install rsync to skip that
    cmd=(scp "${files[@]}" "$dest")
fi

echo "Uploading to $dest:"
printf '  %s\n' "${files[@]##*/}"
if $dry_run; then
    echo "Dry run, would run: ${cmd[*]}"
    [[ -n $SF_API_KEY ]] && echo "Dry run, would make it the default download: PUT $url"
    exit 0
fi

"${cmd[@]}"

if [[ -n $SF_API_KEY ]]; then
    echo "Making $name the default download..."
    # the key goes in on stdin, not the command line, so other users' ps doesn't show it
    printf %s "$SF_API_KEY" | curl -fsS -H "Accept: application/json" -X PUT \
        -d "default=windows&default=mac&default=linux&default=bsd&default=solaris&default=others" \
        --data-urlencode "api_key@-" "$url" >/dev/null \
        || die "uploaded, but setting the default download failed"
fi
echo "Done: $url"
