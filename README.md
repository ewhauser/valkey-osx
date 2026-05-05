# valkey-osx

Unofficial nightly macOS arm64 (Apple Silicon) builds of [Valkey](https://github.com/valkey-io/valkey), published as immutable GitHub releases.

A nightly GitHub Actions job checks the upstream Valkey repo for the latest stable tag and, if it has not already been built here, builds it on a `macos-15` runner and publishes the artifacts as a release `v<VERSION>`. Once published, a release is never overwritten.

## Variants

Each release ships two tarballs:

| Tarball | TLS | Notes |
|---|---|---|
| `valkey-<VERSION>-darwin-arm64.tar.gz` | no | Built with `make BUILD_TLS=no`. |
| `valkey-<VERSION>-darwin-arm64-openssl.tar.gz` | yes | Built with `make BUILD_TLS=yes` against a privately-built **static** OpenSSL. No runtime OpenSSL dependency — `otool -L` reports no `libssl`/`libcrypto` references. |

Pick the `-openssl` variant if you want to use `--tls-port` / `--tls-cert-file` / etc. without installing OpenSSL separately.

## Install

Replace `<VERSION>` with e.g. `9.0.3`. Replace `<PKG>` with either `valkey-<VERSION>-darwin-arm64` or `valkey-<VERSION>-darwin-arm64-openssl`.

```sh
curl -LO https://github.com/<OWNER>/valkey-osx/releases/download/v<VERSION>/<PKG>.tar.gz
tar xzf <PKG>.tar.gz
xattr -dr com.apple.quarantine <PKG>
./<PKG>/bin/valkey-server --version
```

The `xattr -dr com.apple.quarantine` step is required because the binaries are not Apple-signed/notarized.

## Verify

```sh
curl -LO https://github.com/<OWNER>/valkey-osx/releases/download/v<VERSION>/<PKG>.tar.gz.sha256
shasum -a 256 -c <PKG>.tar.gz.sha256
```

## Contents

Each tarball ships these binaries under `bin/`:

- `valkey-server`
- `valkey-cli`
- `valkey-benchmark`
- `valkey-sentinel`
- `valkey-check-aof`
- `valkey-check-rdb`

## Building a specific version manually

Go to **Actions → Release → Run workflow** and enter a Valkey version (e.g. `8.1.6`). Leaving the input blank picks up the latest upstream stable tag.

## How the nightly works

1. `scripts/discover.sh` queries upstream releases, filters to stable tags (`MAJOR.MINOR.PATCH`), picks the newest, and skips if `v<NEWEST>` is already a release here.
2. `scripts/build.sh` downloads the upstream source tarball by commit SHA, builds a private static OpenSSL from a pinned commit, then builds Valkey twice — once with `BUILD_TLS=no` and once with `BUILD_TLS=yes` linked against the static archives — and produces both tarballs plus their `.sha256` and a shared `source.json` provenance sidecar.
3. `scripts/release.sh` creates the GitHub release with all assets and a build-provenance attestation covering both tarballs. If the tag already exists, it exits without touching anything.

## Disclaimer

Not affiliated with the Valkey project. Built from upstream source as-is.
