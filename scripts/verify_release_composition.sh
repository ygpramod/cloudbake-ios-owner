#!/bin/bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

temporary_derived_data=""
derived_data_path="${RELEASE_VERIFICATION_DERIVED_DATA:-}"

if [[ -z "$derived_data_path" ]]; then
  temporary_derived_data="$(mktemp -d "${TMPDIR:-/tmp}/cloudbake-release.XXXXXX")"
  derived_data_path="$temporary_derived_data"
fi

cleanup() {
  if [[ -n "$temporary_derived_data" ]]; then
    rm -rf "$temporary_derived_data"
  fi
}
trap cleanup EXIT

echo "Building the Release owner app for composition verification."
xcodebuild build \
  -quiet \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO

app_bundle="$derived_data_path/Build/Products/Release-iphoneos/CloudBakeOwner.app"
if [[ ! -d "$app_bundle" ]]; then
  echo "Release verification failed: expected app bundle not found at $app_bundle." >&2
  exit 1
fi

forbidden_keys=(
  "CLOUDBAKE_TEST"
  "CLOUDBAKE_SEED"
  "CLOUDBAKE_USE_IN_MEMORY_DATABASE"
  "CLOUDBAKE_INITIAL_DESTINATION"
)

found_forbidden_key=false
for key in "${forbidden_keys[@]}"; do
  if LC_ALL=C grep -R -a -F -l -- "$key" "$app_bundle" >/dev/null; then
    echo "Release verification failed: $key is present in the Release app bundle." >&2
    found_forbidden_key=true
  fi
done

if [[ "$found_forbidden_key" == true ]]; then
  exit 1
fi

echo "Release composition is clean: no acceptance environment keys are present."
