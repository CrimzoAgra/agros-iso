#!/bin/bash
#
# Uploads a built ISO, with its .sha256, .sig and .pkgs.txt, to SourceForge's file release system.
#
#   ./upload-iso.sh [-n|--dry-run] [--signed] [iso]
#   ./upload-iso.sh --check      the settings and the SSH key work (the ISO workflow, before its build)
# -n, --dry-run shows what would go up, and where, without connecting.
# It refuses an ISO that doesn't match its .sha256, or whose .sig isn't a good signature by AgrOS's key (agros.asc);
# --signed also refuses one without a .sig (the ISO workflow: never published unsigned). A refusal exits with 65, which
# no retry changes (any other failure, a dropped connection, may pass the next time).
#
# Without an ISO it takes the newest in out/desktop. Settings come from the environment or from
# ~/.config/agros-iso/upload.conf (the environment wins):
#   SF_USER     SourceForge user name (its SSH key must be in the account's settings)
#   SF_PROJECT  SourceForge project (the short name in https://sourceforge.net/projects/<project>)
#   SF_FOLDER   folder in the project's Files [default: iso]
#   SF_API_KEY  optional: makes the uploaded ISO the project's default download

set -euo pipefail
src_dir=$(dirname "$(readlink -f "$0")")
# (the build's messages and helpers: die, warning, newest_iso, verify_agros_sig, invoking_user)
source "$src_dir/util-msg.sh"
source "$src_dir/util.sh"

# Run with sudo (buildiso.sh -u): upload as the user who ran it, with their SSH key and config
if run_by_sudo; then
    as_invoking_user "$0" "$@"
    exit
fi

# The ISO refused: what it is won't change on a retry (iso.yml stops on it). Not 1-35 (rsync's), 255 (ssh's, die's)
refuse() {
    error "$@"
    exit 65
}

dry_run=false check=false signed=false
iso=
for arg in "$@"; do
    case $arg in
        -n|--dry-run) dry_run=true ;;
        --check) check=true ;;
        --signed) signed=true ;;
        -h|--help) sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option %s" "$arg" ;;
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
[[ -n $SF_USER ]] || die "SF_USER isn't set: put SF_USER=<your SourceForge user> in %s (or the environment)" "$conf"
[[ -n $SF_PROJECT ]] || die "SF_PROJECT isn't set: put SF_PROJECT=<project> in %s (or the environment)" "$conf"
[[ -n $SF_FOLDER ]] || die "SF_FOLDER is empty"
if $check; then
    # (SourceForge's file server takes SFTP only: a listing of the project's folder, without a password prompt)
    if ! out=$(echo "ls /home/frs/project/$SF_PROJECT" | sftp -b - -o BatchMode=yes -o ConnectTimeout=15 "$SF_USER@frs.sourceforge.net" 2>&1); then
        # (the first connection: the server's key not known yet, which only a connection by hand can confirm)
        grep -q 'Host key verification failed' <<<"$out" &&
            die "SourceForge's server isn't known yet: connect once by hand (sftp %s@frs.sourceforge.net), check its fingerprint against SourceForge's page, answer yes, then bye" "$SF_USER"
        die "can't reach SourceForge as %s with your SSH key (is the key in your SourceForge account, the project %s yours?): %s" "$SF_USER" "$SF_PROJECT" "$(tail -1 <<<"$out")"
    fi
    msg "SourceForge: %s, project %s, folder %s: OK" "$SF_USER" "$SF_PROJECT" "$SF_FOLDER"
    exit 0
fi

if [[ -z $iso ]]; then
    iso=$(newest_iso) || true
    [[ -n $iso ]] || refuse "no ISO in %s (build one, or give its path)" "$(iso_out_dir)"
fi
[[ -f $iso && $iso == *.iso ]] || refuse "%s isn't an ISO file" "$iso"
iso=$(readlink -f "$iso")
dir=${iso%/*} name=${iso##*/}

# Refuse an ISO whose checksum or signature doesn't check out
[[ -f $iso.sha256 ]] || refuse "%s.sha256 is missing" "$name"
msg "Checking %s.sha256..." "$name"
(cd "$dir" && sha256sum --quiet -c "$name.sha256") || refuse "%s doesn't match its .sha256" "$name"
if [[ -f $iso.sig ]]; then
    msg "Checking %s.sig..." "$name"
    verify_agros_sig "$iso" ||
        refuse "%s.sig isn't a good signature by AgrOS's key %s (agros.asc): a bad signature, or another key's" "$name" "$(key_fpr "$src_dir/agros.asc")"
    msg2 "Good signature by AgrOS's key"
elif $signed; then
    refuse "no %s.sig: not uploaded unsigned (--signed). Is AgrOS's key, %s, in %s's keyring?" "$name" "$(key_fpr "$src_dir/agros.asc")" "$(invoking_user)"
else
    warning "no %s.sig, the ISO goes up unsigned" "$name"
fi

files=("$iso")
for f in "$iso.sha256" "$iso.sig" "${iso%.iso}.pkgs.txt"; do
    [[ -f $f ]] && files+=("$f")
done

dest="$SF_USER@frs.sourceforge.net:/home/frs/project/$SF_PROJECT/$SF_FOLDER/"
url="https://sourceforge.net/projects/$SF_PROJECT/files/$SF_FOLDER/$name"
if command -v rsync >/dev/null; then
    # rsync creates the last folder of the path. Each file goes up under a hidden temporary name and gets its own at
    # the end; no --partial, which named a cut-off one as the finished file (and SourceForge refuses --partial-dir's
    # folder). Progress only in a terminal (in CI: a line a second)
    cmd=(rsync -e ssh --chmod=F644 "${files[@]}" "$dest")
    [[ -t 1 ]] && cmd+=(--progress)
else
    # shortcut: scp doesn't create the folder, it must exist in the project's Files; install rsync to skip that
    cmd=(scp "${files[@]}" "$dest")
fi

msg "Uploading to %s:" "$dest"
printf '  %s\n' "${files[@]##*/}"
if $dry_run; then
    echo "Dry run, would run: ${cmd[*]}"
    [[ -n $SF_API_KEY ]] && echo "Dry run, would make it the default download: PUT $url"
    exit 0
fi

"${cmd[@]}"

if [[ -n $SF_API_KEY ]]; then
    msg "Making %s the default download..." "$name"
    # the key goes in on stdin, not the command line, so other users' ps doesn't show it
    printf %s "$SF_API_KEY" | curl -fsS -H "Accept: application/json" -X PUT \
        -d "default=windows&default=mac&default=linux&default=bsd&default=solaris&default=others" \
        --data-urlencode "api_key@-" "$url" >/dev/null \
        || warning "uploaded, but setting the default download failed: set it in the project's Files (the file's i button)"
fi
msg "Done: %s" "$url"
