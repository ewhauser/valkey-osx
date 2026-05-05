#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: build.sh <version> <sha>}"
SHA="${2:?usage: build.sh <version> <sha>}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "build: invalid version: $VERSION" >&2
  exit 1
fi
if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "build: invalid sha: $SHA" >&2
  exit 1
fi

ARCH="darwin-arm64"
PKG="valkey-${VERSION}-${ARCH}"

# Fetch by commit SHA so the source is content-addressed, not tag-addressed.
curl -fLo valkey-source.tar.gz "https://github.com/valkey-io/valkey/archive/${SHA}.tar.gz"
SRC_SHA256=$(shasum -a 256 valkey-source.tar.gz | awk '{print $1}')
echo "build: source tarball SHA-256 = $SRC_SHA256"

tar xzf valkey-source.tar.gz
mv "valkey-${SHA}" "valkey-${VERSION}"

cd "valkey-${VERSION}"
make BUILD_TLS=no -j"$(sysctl -n hw.ncpu)"

OUT="dist/${PKG}"
mkdir -p "$OUT/bin"
cp \
  src/valkey-server \
  src/valkey-cli \
  src/valkey-benchmark \
  src/valkey-sentinel \
  src/valkey-check-aof \
  src/valkey-check-rdb \
  "$OUT/bin/"

cd dist
tar -czf "${PKG}.tar.gz" "${PKG}"
shasum -a 256 "${PKG}.tar.gz" > "${PKG}.tar.gz.sha256"

jq -n \
  --arg repo 'valkey-io/valkey' \
  --arg tag "$VERSION" \
  --arg commit "$SHA" \
  --arg src_sha256 "$SRC_SHA256" \
  '{upstream_repo: $repo, upstream_tag: $tag, upstream_commit: $commit, source_tarball_sha256: $src_sha256}' \
  > "${PKG}.source.json"

echo "build: produced $(pwd)/${PKG}.tar.gz"
