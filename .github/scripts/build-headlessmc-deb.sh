#!/usr/bin/env bash
# Builds the deb of a HeadlessMc release that has no deb assets, from its native executable.
# Newer releases attach debs built by headlesshq/headlessmc (packaging/nfpm.yaml), keep this in sync with it.
# Usage: build-headlessmc-deb.sh <tag> <amd64|arm64> <output .deb>
# Requires: gh (authenticated via GH_TOKEN), nfpm.
set -euo pipefail

REPO="headlesshq/headlessmc"
COMPLETIONS="headlessmc-commands/src/main/resources/io/github/headlesshq/headlessmc/commands/completions"

if [[ "$#" -ne 3 ]]; then
  echo "Usage: $0 <tag> <amd64|arm64> <output .deb>" >&2
  exit 1
fi

tag="$1"
arch="$2"
out="$(realpath -m "$3")"
case "$arch" in
  amd64) native=x64 ;;
  arm64) native=arm64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh release download "$tag" --repo "$REPO" --pattern "headlessmc-launcher-linux-$native" --output "$work/headlessmc"
chmod 755 "$work/headlessmc"

# fetches a file of the headlessmc repository at the tag
fetch() {
  gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$1?ref=$tag" > "$2" 2>/dev/null
}

fetch LICENSE "$work/LICENSE"
cat > "$work/package" <<'EOF'
This file marks a HeadlessMc that has been installed by a package manager.
Update HeadlessMc with your package manager instead of replacing /usr/bin/headlessmc.
EOF

# Releases before the shell completions have no completion scripts and no __complete command,
# the scripts would only call a command that does not exist.
completions=""
if fetch "$COMPLETIONS/headlessmc.bash" "$work/headlessmc.bash" \
  && fetch "$COMPLETIONS/headlessmc.zsh" "$work/headlessmc.zsh" \
  && fetch "$COMPLETIONS/headlessmc.fish" "$work/headlessmc.fish"; then
  echo "Including the shell completions of $tag" >&2
  completions="
  - src: $work/headlessmc.bash
    dst: /usr/share/bash-completion/completions/headlessmc
    file_info:
      mode: 0644
  - src: $work/headlessmc.fish
    dst: /usr/share/fish/vendor_completions.d/headlessmc.fish
    file_info:
      mode: 0644
  - src: $work/headlessmc.zsh
    dst: /usr/share/zsh/vendor-completions/_headlessmc
    file_info:
      mode: 0644"
else
  echo "$tag has no shell completions" >&2
fi

# nfpm turns 3.0.0-RC8 into 3.0.0~RC8, so release candidates are sorted before the final release.
# The native executable links against libc.so.6 (up to GLIBC_2.34) and libz.so.1.
cat > "$work/nfpm.yaml" <<YAML
name: headlessmc
arch: $arch
platform: linux
version: $tag
version_schema: semver
release: 1
section: games
priority: optional
maintainer: HeadlessHQ <https://github.com/headlesshq/headlessmc>
vendor: HeadlessHQ
homepage: https://github.com/headlesshq/headlessmc
license: MIT
description: |-
  A command line launcher for Minecraft Java Edition.
  HeadlessMc runs in your terminal and can also run the Minecraft client
  in headless mode, e.g. on CI/CD runners.
depends:
  - libc6 (>= 2.34)
  - zlib1g
recommends:
  - bash-completion
contents:
  - src: $work/headlessmc
    dst: /usr/bin/headlessmc
    file_info:
      mode: 0755
  - src: $work/LICENSE
    dst: /usr/share/doc/headlessmc/copyright
    file_info:
      mode: 0644
  - src: $work/package
    dst: /usr/share/headlessmc/package
    file_info:
      mode: 0644$completions
YAML

mkdir -p "$(dirname "$out")"
nfpm package --config "$work/nfpm.yaml" --packager deb --target "$out"
