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
PKG_BASE="valkey-${VERSION}-${ARCH}"
PKG_TLS="valkey-${VERSION}-${ARCH}-openssl"

# OpenSSL pin used for the static-TLS variant. Update both fields together
# and re-verify the SHA-256 against a freshly-downloaded archive.
OPENSSL_VERSION="3.5.6"
OPENSSL_SHA="286ddeaac037533bbdce65b3c689e3f7ffebf0f6"
OPENSSL_SRC_SHA256_EXPECTED="135c4c043db5d480d7dd4d3c0e96f0cb3cbee574e48c3cc505c540e65ffa1746"

WORK="$(pwd)"

# --- Fetch Valkey source by commit SHA (content-addressed). ---
curl -fLo valkey-source.tar.gz "https://github.com/valkey-io/valkey/archive/${SHA}.tar.gz"
SRC_SHA256=$(shasum -a 256 valkey-source.tar.gz | awk '{print $1}')
echo "build: valkey source SHA-256 = $SRC_SHA256"

# --- Fetch and build a static OpenSSL into a private prefix. ---
curl -fLo openssl-source.tar.gz "https://github.com/openssl/openssl/archive/${OPENSSL_SHA}.tar.gz"
OPENSSL_SRC_SHA256=$(shasum -a 256 openssl-source.tar.gz | awk '{print $1}')
echo "build: openssl source SHA-256 = $OPENSSL_SRC_SHA256"
if [[ "$OPENSSL_SRC_SHA256" != "$OPENSSL_SRC_SHA256_EXPECTED" ]]; then
  echo "build: openssl source SHA-256 mismatch (expected $OPENSSL_SRC_SHA256_EXPECTED)" >&2
  exit 1
fi

OPENSSL_PREFIX="${WORK}/openssl-prefix"
tar xzf openssl-source.tar.gz
(
  cd "openssl-${OPENSSL_SHA}"
  # Static archives only; skip tests/docs/apps/engine to keep the build fast.
  # Do NOT add no-deprecated — Valkey's tls.c uses SSL_get_peer_certificate.
  ./Configure darwin64-arm64-cc no-shared no-tests no-docs no-apps no-engine \
    --prefix="$OPENSSL_PREFIX" \
    --openssldir="$OPENSSL_PREFIX/ssl" >/dev/null
  make -j"$(sysctl -n hw.ncpu)" >/dev/null
  make install_sw >/dev/null
)
[[ -f "$OPENSSL_PREFIX/lib/libssl.a" && -f "$OPENSSL_PREFIX/lib/libcrypto.a" ]] || {
  echo "build: openssl static archives missing under $OPENSSL_PREFIX" >&2
  exit 1
}

# --- Unpack Valkey once; we'll build it twice (no-TLS and TLS). ---
tar xzf valkey-source.tar.gz
mv "valkey-${SHA}" "valkey-${VERSION}"
cd "valkey-${VERSION}"

NCPU=$(sysctl -n hw.ncpu)
DIST="$(pwd)/dist"
mkdir -p "$DIST"

BINS=(valkey-server valkey-cli valkey-benchmark valkey-sentinel valkey-check-aof valkey-check-rdb)

package_variant() {
  local out_dir="$1"
  mkdir -p "${out_dir}/bin"
  for b in "${BINS[@]}"; do cp "src/$b" "${out_dir}/bin/"; done
}

# --- Build #1: no-TLS (the original, unchanged tarball name). ---
make BUILD_TLS=no -j"$NCPU"
package_variant "${DIST}/${PKG_BASE}"
make distclean

# --- Build #2: static-OpenSSL TLS. ---
# Override LIBSSL_LIBS / LIBCRYPTO_LIBS directly with absolute paths to our
# .a archives — pkg-config alone falls back to dynamic linking against any
# libssl/libcrypto dylib the linker finds on PATH.
make BUILD_TLS=yes -j"$NCPU" \
  PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig" \
  LIBSSL_LIBS="$OPENSSL_PREFIX/lib/libssl.a" \
  LIBCRYPTO_LIBS="$OPENSSL_PREFIX/lib/libcrypto.a" \
  OPENSSL_CFLAGS="-I$OPENSSL_PREFIX/include"

# Hard fail if anything still has a dynamic ssl/crypto reference.
for b in valkey-server valkey-cli; do
  if otool -L "src/$b" | grep -iqE 'libssl|libcrypto'; then
    echo "build: $b is dynamically linked against ssl/crypto:" >&2
    otool -L "src/$b" | grep -iE 'libssl|libcrypto' >&2
    exit 1
  fi
done

package_variant "${DIST}/${PKG_TLS}"

# --- Tarball + checksum each variant. ---
cd "$DIST"
for pkg in "$PKG_BASE" "$PKG_TLS"; do
  tar -czf "${pkg}.tar.gz" "${pkg}"
  shasum -a 256 "${pkg}.tar.gz" > "${pkg}.tar.gz.sha256"
done

# --- Source provenance sidecar. ---
jq -n \
  --arg repo 'valkey-io/valkey' \
  --arg tag "$VERSION" \
  --arg commit "$SHA" \
  --arg src_sha256 "$SRC_SHA256" \
  --arg openssl_version "$OPENSSL_VERSION" \
  --arg openssl_commit "$OPENSSL_SHA" \
  --arg openssl_src_sha256 "$OPENSSL_SRC_SHA256" \
  '{
     upstream_repo: $repo,
     upstream_tag: $tag,
     upstream_commit: $commit,
     source_tarball_sha256: $src_sha256,
     variants: {
       default:  { tarball: "'"${PKG_BASE}"'.tar.gz", tls: false },
       openssl:  {
         tarball: "'"${PKG_TLS}"'.tar.gz",
         tls: true,
         openssl: {
           version: $openssl_version,
           commit: $openssl_commit,
           source_tarball_sha256: $openssl_src_sha256,
           link: "static"
         }
       }
     }
   }' \
  > "${PKG_BASE}.source.json"

echo "build: produced $(pwd)/${PKG_BASE}.tar.gz"
echo "build: produced $(pwd)/${PKG_TLS}.tar.gz"
