#!/usr/bin/env bash
# Captures App Store screenshots on each simulator and exports them as JPEGs
# (no alpha channel, as App Store Connect requires) to marketing/screenshots/out/.
# Needs a Mac with Xcode (iOS 27.1 SDK or later) and xcodegen.
#
# Usage: scripts/screenshots.sh ["iPhone 18 Pro" "iPhone 18 Pro Max" ...]
# Set DUO_SIM to an iPhone Duo simulator name to add its shots.
# Nothing is uploaded or submitted.
set -euo pipefail
cd "$(dirname "$0")/.."

SIMS=("$@")
if [[ ${#SIMS[@]} -eq 0 ]]; then
  SIMS=("iPhone 18 Pro" "iPhone 18 Pro Max")
fi
if [[ -n "${DUO_SIM:-}" ]]; then
  SIMS+=("$DUO_SIM")
fi

OUT="marketing/screenshots/out"
mkdir -p "$OUT" build
(cd App && xcodegen generate)

# Runs the named screenshot tests on one simulator and exports them as JPEGs.
# Usage: run_shots <simulator> <bundle slug> <test>...
run_shots() {
  local sim="$1" tag="$2"
  shift 2
  local only=()
  for t in "$@"; do only+=("-only-testing:HingelingUITests/$t"); done
  local bundle="build/screenshots-$tag.xcresult"
  rm -rf "$bundle"
  TEST_RUNNER_HINGELING_SCREENSHOTS=1 xcodebuild \
    -project App/Hingeling.xcodeproj \
    -scheme Hingeling \
    -destination "platform=iOS Simulator,name=$sim,OS=latest" \
    "${only[@]}" \
    -resultBundlePath "$bundle" \
    CODE_SIGNING_ALLOWED=NO \
    test

  local raw="build/screenshots-raw/$tag"
  rm -rf "$raw" && mkdir -p "$raw"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$raw"
  # The manifest maps exported files to the attachment names given in ScreenshotTests.
  python3 - "$raw" "$OUT/$slug" <<'PY'
import json, os, subprocess, sys
raw, out = sys.argv[1], sys.argv[2]
for test in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        stem = name.split("_")[0].rsplit(".", 1)[0]
        dest = os.path.join(out, stem + ".jpg")
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best",
                        os.path.join(raw, a["exportedFileName"]), "--out", dest],
                       check=True, stdout=subprocess.DEVNULL)
        size = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", dest],
                              check=True, capture_output=True, text=True).stdout.split()
        print(f"{dest}: {size[-3]} x {size[-1]}")
PY
}

for SIM in "${SIMS[@]}"; do
  echo "== $SIM"
  xcrun simctl boot "$SIM" 2>/dev/null || true
  # A tidy status bar: 9:41, full battery and signal.
  xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 --dataNetwork wifi || true

  slug=$(echo "$SIM" | tr '[:upper:] ' '[:lower:]-')
  rm -rf "build/screenshots-raw/$slug" && mkdir -p "$OUT/$slug"

  if [[ "$SIM" == *Duo* ]]; then
    # The -fold argument only sets the app's posture; the simulator's own
    # display has to match it. Shot 1 is taken closed (outer display), the
    # rest open (inner display), in separate runs. Shot 4 is standard-iPhone only.
    read -r -p "Close the $SIM simulator so the outer display shows, then press Return. "
    run_shots "$SIM" "$slug-closed" ScreenshotTests/test1Glance
    read -r -p "Open the $SIM simulator so the inner display shows, then press Return. "
    run_shots "$SIM" "$slug-open" ScreenshotTests/test2HomeMidFeed ScreenshotTests/test3Stage ScreenshotTests/test5Elder
  else
    run_shots "$SIM" "$slug" ScreenshotTests
  fi
  xcrun simctl status_bar "$SIM" clear || true
done

echo "== Done. Check the sizes above against marketing/screenshots/README.md before uploading anything."
