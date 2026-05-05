#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: release.sh <version> <sha>}"
SHA="${2:?usage: release.sh <version> <sha>}"
TAG="v${VERSION}"
PKG="valkey-${VERSION}-darwin-arm64"
DIST="valkey-${VERSION}/dist"

if gh release view "$TAG" --repo "$OUR_REPO" >/dev/null 2>&1; then
  echo "release: $TAG already exists — leaving untouched (immutable)."
  exit 0
fi

SRC_SHA256=$(jq -r .source_tarball_sha256 "${DIST}/${PKG}.source.json")
TARBALL_SHA256=$(awk '{print $1}' "${DIST}/${PKG}.tar.gz.sha256")
OWNER="${OUR_REPO%%/*}"

NOTES=$(cat <<EOF
Unofficial macOS arm64 build of [valkey-io/valkey@\`${SHA:0:7}\`](https://github.com/valkey-io/valkey/commit/${SHA}) (tag \`${VERSION}\`). Built with \`make BUILD_TLS=no\`.

## Source provenance

- Upstream commit: \`${SHA}\`
- Source tarball SHA-256: \`${SRC_SHA256}\`
- Built artifact SHA-256: \`${TARBALL_SHA256}\`

This release ships a [build provenance attestation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds). Verify with:

\`\`\`
gh attestation verify --owner ${OWNER} ${PKG}.tar.gz
\`\`\`

## Install

\`\`\`
curl -LO https://github.com/${OUR_REPO}/releases/download/${TAG}/${PKG}.tar.gz
tar xzf ${PKG}.tar.gz
xattr -dr com.apple.quarantine ${PKG}
./${PKG}/bin/valkey-server --version
\`\`\`
EOF
)

gh release create "$TAG" \
  --repo "$OUR_REPO" \
  --title "Valkey ${VERSION} (macOS arm64)" \
  --notes "$NOTES" \
  "${DIST}/${PKG}.tar.gz" \
  "${DIST}/${PKG}.tar.gz.sha256" \
  "${DIST}/${PKG}.source.json"
