#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: release.sh <version>}"
TAG="v${VERSION}"
PKG="valkey-${VERSION}-darwin-arm64"
DIST="valkey-${VERSION}/dist"

if gh release view "$TAG" --repo "$OUR_REPO" >/dev/null 2>&1; then
  echo "release: $TAG already exists — leaving untouched (immutable)."
  exit 0
fi

NOTES=$(cat <<EOF
Unofficial macOS arm64 build of [valkey-io/valkey@${VERSION}](https://github.com/valkey-io/valkey/releases/tag/${VERSION}). Built with \`make BUILD_TLS=no\`.

Install:

\`\`\`
curl -LO https://github.com/${OUR_REPO}/releases/download/${TAG}/${PKG}.tar.gz
tar xzf ${PKG}.tar.gz
xattr -dr com.apple.quarantine ${PKG}
./${PKG}/bin/valkey-server --version
\`\`\`

Verify checksum:

\`\`\`
curl -LO https://github.com/${OUR_REPO}/releases/download/${TAG}/${PKG}.tar.gz.sha256
shasum -a 256 -c ${PKG}.tar.gz.sha256
\`\`\`
EOF
)

gh release create "$TAG" \
  --repo "$OUR_REPO" \
  --title "Valkey ${VERSION} (macOS arm64)" \
  --notes "$NOTES" \
  "${DIST}/${PKG}.tar.gz" \
  "${DIST}/${PKG}.tar.gz.sha256"
