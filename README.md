# HeadlessHQ apt repository

[apt](https://wiki.debian.org/Apt) repository for HeadlessHQ projects, for Debian, Ubuntu and their derivatives
on amd64 and arm64.

```shell
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://headlesshq.github.io/apt/headlesshq.gpg | sudo tee /etc/apt/keyrings/headlesshq.gpg > /dev/null
curl -fsSL https://headlesshq.github.io/apt/headlesshq.sources | sudo tee /etc/apt/sources.list.d/headlesshq.sources > /dev/null
sudo apt update
sudo apt install headlessmc
```

`sudo apt update && sudo apt upgrade` then updates HeadlessMc together with the rest of your system.
The packages require glibc 2.34 or newer, they are tested on Debian 12 and 13 and Ubuntu 22.04, 24.04 and 26.04.

## How it works

The repository is not stored in git. The [Update headlessmc](.github/workflows/update-headlessmc.yml) workflow
runs for every HeadlessMc release (and daily as a fallback), builds the repository from the latest releases
and deploys it to GitHub Pages, after installing and upgrading headlessmc from it on Debian and Ubuntu.

| Script | |
|---|---|
| [`select-headlessmc-releases.sh`](.github/scripts/select-headlessmc-releases.sh) | Picks the latest releases (`KEEP`, default 3). |
| [`collect-headlessmc.sh`](.github/scripts/collect-headlessmc.sh) | Downloads the debs of each release, releases without debs get them built from their native executables by [`build-headlessmc-deb.sh`](.github/scripts/build-headlessmc-deb.sh). |
| [`build-repository.sh`](.github/scripts/build-repository.sh) | Generates `dists/` with `apt-ftparchive`, signs it and adds the public key and `headlesshq.sources`. |
| [`test-repository.sh`](.github/scripts/test-repository.sh) | Adds the repository to a container like users do, installs the oldest release and upgrades it. |

### Setup

1. Create a signing key that does not expire. It is hard to rotate, as every user has to download the new one,
   so store the backup somewhere safe, e.g. a password manager:
   ```shell
   export GNUPGHOME="$(mktemp -d)"
   gpg --batch --passphrase '' --quick-gen-key "HeadlessHQ apt repository" ed25519 sign never
   gpg --armor --export-secret-keys "HeadlessHQ apt repository" > apt-signing-key.asc
   gh secret set APT_SIGNING_KEY --repo headlesshq/apt < apt-signing-key.asc
   rm -rf "$GNUPGHOME"   # then move apt-signing-key.asc into your backup
   ```
   With a passphrase, also set it as the `APT_SIGNING_PASSPHRASE` secret.
2. Make this repository public and set *Settings → Pages → Source* to *GitHub Actions*.
3. `gh variable set APT_PAGES_ENABLED --body true --repo headlesshq/apt`
4. Run the *Update headlessmc* workflow manually.

The release job of headlesshq/headlessmc triggers the update with a `headlessmc-release` repository dispatch.
