#!/usr/bin/env bash
set -euo pipefail

emit() {
  printf 'targets=%s\n' "$1" >> "$GITHUB_OUTPUT"
  echo "discover: targets=$1"
}

VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

if [[ -n "${INPUT_VERSION:-}" ]]; then
  if [[ ! "$INPUT_VERSION" =~ $VERSION_RE ]]; then
    echo "discover: rejecting malformed INPUT_VERSION: $INPUT_VERSION" >&2
    exit 1
  fi
  VERSION="$INPUT_VERSION"
else
  VERSION=$(gh api repos/valkey-io/valkey/releases --paginate \
      -q '.[] | select(.prerelease == false) | .tag_name' \
    | grep -E "$VERSION_RE" \
    | sort -V \
    | tail -1)

  if [[ -z "$VERSION" ]]; then
    echo "discover: no stable upstream tags found" >&2
    emit '[]'
    exit 0
  fi
fi

if gh release view "v$VERSION" --repo "$OUR_REPO" >/dev/null 2>&1; then
  echo "discover: v$VERSION already released — nothing to do"
  emit '[]'
  exit 0
fi

# Resolve the upstream tag to an immutable commit SHA. We pass this through
# to build.sh so the source download is content-addressed (resilient to
# upstream tag mutation).
SHA=$(gh api "repos/valkey-io/valkey/commits/${VERSION}" -q '.sha')
if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "discover: failed to resolve $VERSION to a commit SHA: $SHA" >&2
  exit 1
fi

emit "$(jq -nc --arg v "$VERSION" --arg s "$SHA" '[{version: $v, sha: $s}]')"
