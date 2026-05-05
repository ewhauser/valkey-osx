#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: build.sh <version>}"
ARCH="darwin-arm64"
PKG="valkey-${VERSION}-${ARCH}"

curl -fLO "https://github.com/valkey-io/valkey/archive/refs/tags/${VERSION}.tar.gz"
tar xzf "${VERSION}.tar.gz"

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

echo "build: produced $(pwd)/${PKG}.tar.gz"
