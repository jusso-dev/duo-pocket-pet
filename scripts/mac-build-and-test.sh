#!/usr/bin/env bash
# Builds and tests Hingeling on a Mac. Needs Xcode with the iOS 27.1 SDK or later.
# Usage: scripts/mac-build-and-test.sh [simulator name]
# With no name it uses the newest available iPhone simulator, as CI does.
set -euo pipefail
cd "$(dirname "$0")/.."

newest_iphone() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = [int(x) for x in runtime.rsplit(".iOS-", 1)[1].split("-")]
    for d in devices:
        if d["name"].startswith("iPhone"):
            key = (version, d["name"])
            if best is None or key > best[0]:
                best = (key, d["name"])
print(best[1] if best else "")
'
}

SIM="${1:-}"
if [[ -z "$SIM" ]]; then
  SIM="$(newest_iphone)"
  [[ -n "$SIM" ]] || { echo "No iPhone simulator is available. Create one in Xcode, or pass a name."; exit 1; }
fi
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
