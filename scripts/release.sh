#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: release.sh <version> <sha>}"
SHA="${2:?usage: release.sh <version> <sha>}"
TAG="v${VERSION}"
PKG_BASE="valkey-${VERSION}-darwin-arm64"
PKG_TLS="valkey-${VERSION}-darwin-arm64-openssl"
DIST="valkey-${VERSION}/dist"

if gh release view "$TAG" --repo "$OUR_REPO" >/dev/null 2>&1; then
  echo "release: $TAG already exists — leaving untouched (immutable)."
  exit 0
fi

SRC_SHA256=$(jq -r .source_tarball_sha256 "${DIST}/${PKG_BASE}.source.json")
TARBALL_SHA256=$(awk '{print $1}' "${DIST}/${PKG_BASE}.tar.gz.sha256")
TLS_TARBALL_SHA256=$(awk '{print $1}' "${DIST}/${PKG_TLS}.tar.gz.sha256")
OPENSSL_VERSION=$(jq -r .variants.openssl.openssl.version "${DIST}/${PKG_BASE}.source.json")
OPENSSL_COMMIT=$(jq -r .variants.openssl.openssl.commit "${DIST}/${PKG_BASE}.source.json")
OWNER="${OUR_REPO%%/*}"

NOTES=$(cat <<EOF
Unofficial macOS arm64 build of [valkey-io/valkey@\`${SHA:0:7}\`](https://github.com/valkey-io/valkey/commit/${SHA}) (tag \`${VERSION}\`).

## Variants

| Tarball | TLS | Notes |
|---|---|---|
| \`${PKG_BASE}.tar.gz\` | no  | Built with \`make BUILD_TLS=no\`. |
| \`${PKG_TLS}.tar.gz\` | yes | Built with \`make BUILD_TLS=yes\` against a privately-built **static** OpenSSL ${OPENSSL_VERSION} (commit \`${OPENSSL_COMMIT:0:7}\`). No runtime OpenSSL dependency. |

## Source provenance

- Upstream commit: \`${SHA}\`
- Source tarball SHA-256: \`${SRC_SHA256}\`
- \`${PKG_BASE}.tar.gz\` SHA-256: \`${TARBALL_SHA256}\`
- \`${PKG_TLS}.tar.gz\` SHA-256: \`${TLS_TARBALL_SHA256}\`

Both tarballs are covered by a [build provenance attestation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds). Verify with:

\`\`\`
gh attestation verify --owner ${OWNER} ${PKG_BASE}.tar.gz
gh attestation verify --owner ${OWNER} ${PKG_TLS}.tar.gz
\`\`\`

## Install

\`\`\`
# pick one
PKG=${PKG_BASE}      # no TLS
PKG=${PKG_TLS}       # static OpenSSL

curl -LO https://github.com/${OUR_REPO}/releases/download/${TAG}/\${PKG}.tar.gz
tar xzf \${PKG}.tar.gz
xattr -dr com.apple.quarantine \${PKG}
./\${PKG}/bin/valkey-server --version
\`\`\`
EOF
)

gh release create "$TAG" \
  --repo "$OUR_REPO" \
  --title "Valkey ${VERSION} (macOS arm64)" \
  --notes "$NOTES" \
  "${DIST}/${PKG_BASE}.tar.gz" \
  "${DIST}/${PKG_BASE}.tar.gz.sha256" \
  "${DIST}/${PKG_TLS}.tar.gz" \
  "${DIST}/${PKG_TLS}.tar.gz.sha256" \
  "${DIST}/${PKG_BASE}.source.json"
