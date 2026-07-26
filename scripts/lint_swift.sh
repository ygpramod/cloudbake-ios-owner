#!/bin/bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

declare -a swift_files=()

if [[ "$#" -gt 0 ]]; then
  for file in "$@"; do
    if [[ "$file" == *.swift && -f "$file" ]]; then
      swift_files+=("$file")
    fi
  done
else
  base_sha="${SWIFT_FORMAT_BASE_SHA:-}"

  if [[ "$base_sha" =~ ^0+$ ]]; then
    base_sha="$(git rev-parse HEAD^)"
  elif [[ -z "$base_sha" ]]; then
    echo "Set SWIFT_FORMAT_BASE_SHA or pass the Swift files to lint." >&2
    exit 2
  fi

  while IFS= read -r file; do
    if [[ -n "$file" && -f "$file" ]]; then
      swift_files+=("$file")
    fi
  done < <(git diff --name-only --diff-filter=ACMR "$base_sha"...HEAD -- '*.swift')
fi

if [[ "${#swift_files[@]}" -eq 0 ]]; then
  echo "No changed Swift files to lint."
  exit 0
fi

echo "Linting ${#swift_files[@]} changed Swift file(s)."
xcrun swift-format lint \
  --strict \
  --configuration "$repository_root/.swift-format" \
  "${swift_files[@]}"
