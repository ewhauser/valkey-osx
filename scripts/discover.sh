#!/usr/bin/env bash
set -euo pipefail

emit() {
  printf 'versions=%s\n' "$1" >> "$GITHUB_OUTPUT"
  echo "discover: versions=$1"
}

if [[ -n "${INPUT_VERSION:-}" ]]; then
  emit "$(jq -nc --arg v "$INPUT_VERSION" '[$v]')"
  exit 0
fi

LATEST=$(gh api repos/valkey-io/valkey/releases --paginate \
    -q '.[] | select(.prerelease == false) | .tag_name' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -1)

if [[ -z "$LATEST" ]]; then
  echo "discover: no stable upstream tags found" >&2
  emit '[]'
  exit 0
fi

if gh release view "v$LATEST" --repo "$OUR_REPO" >/dev/null 2>&1; then
  echo "discover: v$LATEST already released — nothing to do"
  emit '[]'
  exit 0
fi

emit "$(jq -nc --arg v "$LATEST" '[$v]')"
