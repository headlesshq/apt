#!/usr/bin/env bash
# Puts the amd64 and arm64 debs of HeadlessMc releases into the pool of the repository.
# Uses the deb assets of a release, releases before they were published get their debs built from the
# native executables by build-headlessmc-deb.sh instead.
# Usage: collect-headlessmc.sh <site directory> <tag>...
# Requires: gh (authenticated via GH_TOKEN), and nfpm for releases without debs.
set -euo pipefail

REPO="headlesshq/headlessmc"
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 <site directory> <tag>..." >&2
  exit 1
fi

pool="$1/pool/main/h/headlessmc"
shift
mkdir -p "$pool"

for tag in "$@"; do
  assets="$(gh release view "$tag" --repo "$REPO" --json assets --jq '.assets[].name')"
  for arch in amd64 arm64; do
    # named after the tag, GitHub would replace the ~ of the package version 3.0.0~RC8
    deb="headlessmc_${tag}_${arch}.deb"
    if grep -qxF "$deb" <<<"$assets"; then
      echo "Downloading $deb" >&2
      gh release download "$tag" --repo "$REPO" --pattern "$deb" --dir "$pool" --clobber
    else
      echo "$tag has no $deb, building it from the native executable" >&2
      bash "$SCRIPTS/build-headlessmc-deb.sh" "$tag" "$arch" "$pool/$deb"
    fi
  done
done

ls -l "$pool" >&2
