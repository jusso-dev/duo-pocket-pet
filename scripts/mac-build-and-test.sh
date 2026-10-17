#!/usr/bin/env bash
# Builds and tests Hingeling on a Mac. Needs Xcode with the iOS 27.1 SDK or later.
# Usage: scripts/mac-build-and-test.sh [simulator name]
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${1:-iPhone 17}"
DERIVED="${DERIVED_DATA:-$PWD/build/DerivedData}"

echo "== Toolchain"
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }

echo "== Core package tests (macOS)"
swift test

echo "== Generate Xcode project"
(cd App && xcodegen generate)

echo "== Available simulators"
xcrun simctl list devices available | grep -E "iPhone" || true

echo "== Build and test on $SIM"
xcodebuild \
  -project App/Hingeling.xcodeproj \
  -scheme Hingeling \
  -destination "platform=iOS Simulator,name=$SIM,OS=latest" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "build/Hingeling-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  clean build test

if [[ -n "${DUO_SIM:-}" ]]; then
  echo "== Build and test on $DUO_SIM"
  xcodebuild \
    -project App/Hingeling.xcodeproj \
    -scheme Hingeling \
    -destination "platform=iOS Simulator,name=$DUO_SIM,OS=latest" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    test
fi
echo "== Done"
