# valkey-osx

Unofficial nightly macOS arm64 (Apple Silicon) builds of [Valkey](https://github.com/valkey-io/valkey), published as immutable GitHub releases.

A nightly GitHub Actions job checks the upstream Valkey repo for the latest stable tag and, if it has not already been built here, builds it on a `macos-15` runner with `make BUILD_TLS=no` and publishes the tarball as a release `v<VERSION>`. Once published, a release is never overwritten.

## Install

Replace `<VERSION>` with e.g. `9.0.3`.

```sh
curl -LO https://github.com/<OWNER>/valkey-osx/releases/download/v<VERSION>/valkey-<VERSION>-darwin-arm64.tar.gz
tar xzf valkey-<VERSION>-darwin-arm64.tar.gz
xattr -dr com.apple.quarantine valkey-<VERSION>-darwin-arm64
./valkey-<VERSION>-darwin-arm64/bin/valkey-server --version
```

The `xattr -dr com.apple.quarantine` step is required because the binaries are not Apple-signed/notarized.

## Verify

```sh
curl -LO https://github.com/<OWNER>/valkey-osx/releases/download/v<VERSION>/valkey-<VERSION>-darwin-arm64.tar.gz.sha256
shasum -a 256 -c valkey-<VERSION>-darwin-arm64.tar.gz.sha256
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
2. `scripts/build.sh` downloads the upstream source tarball, runs `make BUILD_TLS=no`, and produces `dist/valkey-<VERSION>-darwin-arm64.tar.gz` plus a `.sha256`.
3. `scripts/release.sh` creates the GitHub release with both assets. If the tag already exists, it exits without touching anything.

## Disclaimer

Not affiliated with the Valkey project. Built from upstream source as-is.
