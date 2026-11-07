#!/usr/bin/env bash
# Indexes and signs the apt repository in a site directory, whose pool has been filled by collect-headlessmc.sh,
# and adds the public key, a sources file and an index page, so the directory can be deployed to GitHub Pages.
# Usage: build-repository.sh <site directory> <tag>...
#   The tags are written to releases.txt, which tells later runs which releases the deployed repository contains.
#   APT_SIGNING_KEY         ASCII armored private key that signs the repository.
#   APT_SIGNING_PASSPHRASE  its passphrase, if it has one.
#   ALLOW_EPHEMERAL_KEY     if "true" and APT_SIGNING_KEY is empty, signs with a new throwaway key, for tests.
#   MAX_SITE_MB             fails if the site is larger than this (default 800), GitHub Pages sites may be
#                           at most 1 GB, so new packages or architectures cannot silently break deployments.
# Requires: apt-ftparchive (apt-utils), gpg, gzip.
set -euo pipefail

URL="https://headlesshq.github.io/apt/"
SUITE="stable"
COMPONENT="main"
ARCHITECTURES="amd64 arm64"

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 <site directory> <tag>..." >&2
  exit 1
fi

site="$(realpath "$1")"
shift
cd "$site"

max_mb="${MAX_SITE_MB:-800}"
size_mb="$(du -sm . | cut -f1)"
echo "The site is $size_mb MB (limit $max_mb MB)" >&2
if (( size_mb > max_mb )); then
  echo "The site is larger than $max_mb MB, keep fewer releases (KEEP) or raise MAX_SITE_MB up to the 1 GB limit of GitHub Pages:" >&2
  du -sh pool/*/*/* >&2
  exit 1
fi

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

if [[ -n "${APT_SIGNING_KEY:-}" ]]; then
  gpg --batch --import <<<"$APT_SIGNING_KEY"
elif [[ "${ALLOW_EPHEMERAL_KEY:-}" == "true" ]]; then
  echo "APT_SIGNING_KEY is not set, signing with a throwaway key" >&2
  gpg --batch --passphrase '' --quick-gen-key "HeadlessHQ apt repository (test key)" ed25519 sign never
else
  echo "APT_SIGNING_KEY is not set" >&2
  exit 1
fi

fingerprint="$(gpg --list-secret-keys --with-colons | awk -F: '$1 == "fpr" { print $10; exit }')"
sign=(gpg --batch --yes --pinentry-mode loopback --local-user "$fingerprint")
if [[ -n "${APT_SIGNING_PASSPHRASE:-}" ]]; then
  sign+=(--passphrase "$APT_SIGNING_PASSPHRASE")
else
  sign+=(--passphrase '')
fi

dists="dists/$SUITE"
rm -rf "$dists"
for arch in $ARCHITECTURES; do
  mkdir -p "$dists/$COMPONENT/binary-$arch"
  # only matches *_<arch>.deb, the pool contains the debs of all architectures
  apt-ftparchive --arch "$arch" packages pool > "$dists/$COMPONENT/binary-$arch/Packages"
  gzip -9kf "$dists/$COMPONENT/binary-$arch/Packages"
done

# written outside of dists, so the Release file does not list itself
release="$(mktemp)"
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=HeadlessHQ" \
  -o "APT::FTPArchive::Release::Label=HeadlessHQ" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Architectures=$ARCHITECTURES" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Description=HeadlessHQ apt repository" \
  release "$dists" > "$release"
mv "$release" "$dists/Release"
chmod 644 "$dists/Release"

"${sign[@]}" --clearsign --output "$dists/InRelease" "$dists/Release"
"${sign[@]}" --armor --detach-sign --output "$dists/Release.gpg" "$dists/Release"

# the binary key is what Signed-By expects, the armored one is for humans
gpg --batch --yes --export "$fingerprint" > headlesshq.gpg
gpg --batch --yes --armor --export "$fingerprint" > headlesshq.asc

cat > headlesshq.sources <<EOF
Types: deb
URIs: $URL
Suites: $SUITE
Components: $COMPONENT
Architectures: $ARCHITECTURES
Signed-By: /etc/apt/keyrings/headlesshq.gpg
EOF

printf '%s\n' "$@" > releases.txt

cat > index.html <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>HeadlessHQ apt repository</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 48rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
    pre { background: #f2f2f2; padding: 1rem; overflow-x: auto; }
    @media (prefers-color-scheme: dark) { body { background: #111; color: #ddd; } pre { background: #222; } a { color: #8ab4f8; } }
  </style>
</head>
<body>
  <h1>HeadlessHQ apt repository</h1>
  <p>Debian and Ubuntu packages of <a href="https://github.com/headlesshq/headlessmc">HeadlessMc</a> for amd64 and arm64.</p>
<pre>sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL ${URL}headlesshq.gpg | sudo tee /etc/apt/keyrings/headlesshq.gpg &gt; /dev/null
curl -fsSL ${URL}headlesshq.sources | sudo tee /etc/apt/sources.list.d/headlesshq.sources &gt; /dev/null
sudo apt update
sudo apt install headlessmc</pre>
  <p>Signing key fingerprint: <code>$fingerprint</code></p>
  <p>Contains HeadlessMc $(printf '%s, ' "$@" | sed 's/, $//').</p>
</body>
</html>
EOF

echo "Signed $site with $fingerprint" >&2
