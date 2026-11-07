#!/usr/bin/env bash
# Adds the repository to a Debian or Ubuntu container exactly like users do, installs headlessmc from it
# and, if it contains more than one release, installs the oldest one and upgrades it to the newest one.
# Runs inside the container, with the site served at $APT_URL and mounted at /site.
# Usage: test-repository.sh
set -euo pipefail

APT_URL="${APT_URL:-http://127.0.0.1:8000/}"
export DEBIAN_FRONTEND=noninteractive

install -d -m 0755 /etc/apt/keyrings
cp /site/headlesshq.gpg /etc/apt/keyrings/headlesshq.gpg
sed "s|^URIs: .*|URIs: $APT_URL|" /site/headlesshq.sources > /etc/apt/sources.list.d/headlesshq.sources

apt-get update -q
newest="$(head -n1 /site/releases.txt)"
mapfile -t versions < <(apt-cache madison headlessmc | awk -F'|' '{ gsub(/ /, "", $2); print $2 }')
echo "Available versions: ${versions[*]}"

if (( ${#versions[@]} > 1 )); then
  # madison lists the newest version first
  oldest="${versions[-1]}"
  apt-get install -y -q "headlessmc=$oldest"
  dpkg-query -W headlessmc
  apt-get upgrade -y -q
else
  apt-get install -y -q headlessmc
fi

dpkg-query -W headlessmc
installed="$(headlessmc --version)"
if [[ "$installed" != "$newest" ]]; then
  echo "Expected headlessmc $newest, but got $installed" >&2
  exit 1
fi

test -f /usr/share/headlessmc/package
echo "headlessmc $installed installed from $APT_URL"
