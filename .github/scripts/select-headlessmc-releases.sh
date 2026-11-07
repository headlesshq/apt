#!/usr/bin/env bash
# Prints the HeadlessMc release tags the repository should contain, newest first, one per line.
# Usage: select-headlessmc-releases.sh [tag]
#   KEEP  number of the latest releases to keep (default 2), older ones are dropped from the repository.
#         Upgrading only needs the newest one, the previous one stays so clients whose index is from
#         before a deployment can still download the version it lists.
#   tag   is added if it is not one of the latest releases, e.g. to test an older release.
# Requires: gh (authenticated via GH_TOKEN).
set -euo pipefail

REPO="headlesshq/headlessmc"
KEEP="${KEEP:-2}"
TAG="${1:-}"

tags="$(gh release list --repo "$REPO" --exclude-drafts --limit "$KEEP" --json tagName --jq '.[].tagName')"
if [[ -z "$tags" ]]; then
  echo "No releases found for $REPO" >&2
  exit 1
fi

echo "$tags"
if [[ -n "$TAG" ]] && ! grep -qxF "$TAG" <<<"$tags"; then
  echo "$TAG"
fi
