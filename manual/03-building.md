# Building the ISO

Run the build from the repo's folder, with sudo:

```bash
sudo ./buildiso.sh -p desktop -v -w
```

The build gets half of the CPU at the lowest CPU and disk priority, so the PC stays cool, quiet and usable while it
runs. Add `-a` to give it all of the CPU: faster, but hotter and louder.

## A quick test build

```bash
sudo ./buildiso.sh -p desktop -v -w -f
```

`-f` compresses with zstd instead of xz. It's much faster and makes a bigger ISO. Use it to try out a change, and
build without it for a release.

## Options

```
$ ./buildiso.sh -h
Usage: buildiso.sh [options]
    -c                 Disable clean work dir
    -r                 Enable building in RAM on systems with more than 23GB RAM
    -w                 Remove build directory (not the ISO) after ISO file is built
    -f                 Fast test build: zstd instead of xz (much quicker, a bigger ISO)
    -a                 Use all of the CPU (by default the build gets half: cooler and quieter)
    -u                 Upload the ISO to SourceForge once it is built (upload-iso.sh, as the sudo user)
    -p <profile>       Buildset or profile [default: desktop]
    -v                 Verbose output to log file, show profile detail (-q)
    -h                 This help
```

- `-p desktop` is the only profile there is, and the default.
- Without `-c`, the build first deletes the work folder (`build/`) left by the last build.
- `-r` builds in a temporary folder in RAM, but only on a machine with more than 23 GB of RAM. Without `-w`, the build
  reminds you to delete that folder afterwards.
- `-w` deletes the work folder once the ISO is built. The ISO stays.
- `-u` uploads the ISO once it's built, as in [Publishing the ISO](#publishing-the-iso).

## What you get

Everything ends up in `out/desktop/`, named after the date (`YYMMDD`):

| File | What it is |
|---|---|
| `agros-desktop-linux-YYMMDD.iso` | The ISO |
| `agros-desktop-linux-YYMMDD.iso.sha1`, `.sha256` | Its checksums |
| `agros-desktop-linux-YYMMDD.iso.sig` | Its signature, if the signing key was found |
| `agros-desktop-linux-YYMMDD.pkgs.txt` | Every package on the live system, with its version |

### Checksums and signature

The build makes the checksums and the signature for the ISO it just built, not for the older ones in the folder.

It signs with the key set as `GPGKEY` in `~/.config/pacman/makepkg.conf`, `~/.makepkg.conf` (yours, also under sudo) or `/etc/makepkg.conf`. With none set, it uses AgrOS's key,
`23B6096B42D05E1E`, the one AgrOS's packages are signed with. It looks for the key in the keyring of the user who ran
`sudo`, not root's. If the key isn't there, the build warns "Not signed" and finishes without a signature.

To check an ISO:

```bash
cd out/desktop
sha256sum -c agros-desktop-linux-YYMMDD.iso.sha256
gpg --verify agros-desktop-linux-YYMMDD.iso.sig agros-desktop-linux-YYMMDD.iso
```

## Publishing the ISO

`upload-iso.sh` puts an ISO on [SourceForge](https://sourceforge.net), where people can download it, as other distros
do (GitHub takes at most 2 GB a file; the ISO is about 3.7). Once it's set up, **every change on GitHub publishes a new
ISO by itself** (below); `upload-iso.sh` also works on its own.

### Setting it up, once

1. Create a SourceForge account and a project ([sourceforge.net/create](https://sourceforge.net/create)). The project's
   short name, the one in `https://sourceforge.net/projects/<project>`, is `SF_PROJECT` below.
2. Add your SSH public key (`~/.ssh/id_ed25519.pub`; make one with `ssh-keygen -t ed25519` if you have none) in
   SourceForge's account settings, under **SSH Settings**
   ([sourceforge.net/auth/shell_services](https://sourceforge.net/auth/shell_services)). It can take a few minutes to
   work.
3. Write `~/.config/agros-iso/upload.conf`:

   ```bash
   SF_USER=your-sourceforge-user
   SF_PROJECT=your-project
   SF_FOLDER=iso          # the folder in the project's Files; iso if left out
   #SF_API_KEY=...        # optional, below
   ```

   The same names work as environment variables, which win over the file (not through `sudo`, so use the file with
   `buildiso.sh -u`). Keep this file out of the repo: it's yours, and the API key is a secret.
4. Optional: with `SF_API_KEY` set, the uploaded ISO becomes the project's default download, the big green button on
   its page. The key is the **Releases API Key** in SourceForge's account preferences
   ([sourceforge.net/auth/preferences](https://sourceforge.net/auth/preferences)). Without it, set the default download
   by hand: the file's **i** button in the project's Files.
5. Install `rsync` (`sudo pacman -S rsync`). It shows the progress and resumes a stopped upload. Without it the script
   uses `scp`, which needs the folder (`SF_FOLDER`) to exist in the project's Files already.
6. Check it: `./upload-iso.sh --check` connects with your key and says `OK`, or what's wrong.
7. Turn on automatic publishing on this PC: `sudo ./publish/install.sh` (once; again after changing `publish/`).

### Published by itself

Every 15 minutes a system timer (`agros-iso-publish.timer`) checks GitHub. When this repo's `main` or AgrOS's
packages changed (an agros push, once its CI passed and published them), it publishes a new ISO. You don't need to
watch it or push in any order:

1. it waits while AgrOS's CI is still running, so the ISO never has packages older than what's on GitHub;
2. it checks the SourceForge settings and key (`upload-iso.sh --check`), so a mistake shows before the build;
3. it builds, as root and at low priority, exactly what's on GitHub's `main`, in a copy of its own
   (`/var/lib/agros-iso-publish`). Nothing from your clone runs as root, and what you haven't pushed isn't in it.
   It takes about 30 minutes, and doesn't start on battery;
4. it uploads the ISO as you (`buildiso.sh -u`: your SSH key, gpg key and `upload.conf`).

A notification says when it starts, when it's published, and when it failed and why. A failed commit is tried again
after 6 hours. `./publish-iso.sh` starts a check now (also retrying a failed commit) and shows its log; the log is
always in `journalctl -u agros-iso-publish`.

### Uploading

```bash
./upload-iso.sh --dry-run     # what would go up, and where, without connecting
./upload-iso.sh               # the newest ISO in out/desktop
./upload-iso.sh out/desktop/agros-desktop-linux-YYMMDD.iso
sudo ./buildiso.sh -p desktop -v -w -u    # build, then upload
```

It uploads the ISO with its `.sha256`, `.sig` and `.pkgs.txt` (those that exist) to
`<SF_USER>@frs.sourceforge.net:/home/frs/project/<SF_PROJECT>/<SF_FOLDER>/`. First it checks the ISO against its
`.sha256` and the `.sig` with your keyring, and refuses an ISO that fails either. An ISO without a `.sig` goes up with a
warning. Run with `sudo`, as `buildiso.sh -u` does, it uploads as the user who ran `sudo`, with their SSH key, keyring and
config file.

### Downloading and checking it

The ISO is then at `https://sourceforge.net/projects/<SF_PROJECT>/files/<SF_FOLDER>/`. To check a download, people need
AgrOS's public key: it's [agros.asc](../agros.asc) in this repo (the same key that signs AgrOS's packages). In the
folder with the downloads:

```bash
curl -LO https://raw.githubusercontent.com/CrimzoAgra/agros-iso/main/agros.asc
sha256sum -c agros-desktop-linux-YYMMDD.iso.sha256
gpg --import agros.asc
gpg --fingerprint 23B6096B42D05E1E     # should be BFE9 289F 7759 E521 AE60  CFCD 23B6 096B 42D0 5E1E
gpg --verify agros-desktop-linux-YYMMDD.iso.sig agros-desktop-linux-YYMMDD.iso
```

`Good signature from "AgrOS ..."` means the ISO is the one AgrOS built and signed.

## Put it on a USB stick

Use [balenaEtcher](https://etcher.balena.io), or `dd` (replace `sdX` with the stick; everything on it is erased):

```bash
sudo dd if=out/desktop/agros-desktop-linux-YYMMDD.iso of=/dev/sdX bs=4M status=progress
```

Then boot the computer from the stick. Installing is covered in AgrOS's manual:
[Installing](https://github.com/CrimzoAgra/agros/blob/main/manual/02-installing.md).

Next: [Testing it in a VM](04-testing.md)
