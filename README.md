# Hingeling

Hingeling is a small pixel-art pocket pet for iPhone. It is built for iPhone Duo, Apple's foldable iPhone, and it works on every other iPhone too.

The pet lives in the fold of the phone:

- **Closed:** a closed iPhone Duo works like a compact iPhone, so the app shows a compact glance at your pet and its mood. Closing the phone tucks it in for a nap.
- **Open:** the inner screen becomes the pet's home, where you feed it, clean up after it and play with it.
- **Half folded:** the phone becomes a little stage and the pet puts on a show.
- **Any other iPhone:** you get the same home screen, with a bedtime button in place of the fold.

The repository slug is `duo-pocket-pet` (the working name). The app ships as **Hingeling**, because "PocketPet" is already the name of an existing virtual pet app and of a pet care app. See [Naming](#naming).

## Original design

Hingeling is an original design. The creature, its pixel art, animations, colours, names and game rules were all made for this project. It is not affiliated with, endorsed by or based on any toy brand, game company or virtual pet product, and it is not affiliated with or endorsed by Apple. iPhone and iPhone Duo are trademarks of Apple Inc.

## Status

Early development. The work is tracked in [issues](https://github.com/jusso-dev/duo-pocket-pet/issues) under two milestones, **MVP** and **Later**.

## Layout

```
Package.swift                  Swift package for the platform-free logic
Sources/PocketPetCore/         Pet model, decay and ageing, persistence, fold postures, scene state machine
Tests/PocketPetCoreTests/      Tests that run on Linux and macOS (`swift test`)
App/                           SwiftUI iOS app (XcodeGen `project.yml`), needs a Mac
ci/workflows/                  CI workflows, to be moved into .github/workflows
scripts/                       Helper scripts, including the Mac build and test script
```

The rule of thumb: anything that can be tested without UIKit or SwiftUI lives in `PocketPetCore`. The app target only adapts system APIs into the core types and draws the UI.

## Building

### Core package (Linux or macOS)

```sh
swift build
swift test
```

### iOS app (macOS with Xcode only)

```sh
brew install xcodegen
scripts/mac-build-and-test.sh
```

The script generates `App/Hingeling.xcodeproj`, then builds and tests the app on an iPhone simulator. The iPhone Duo hinge APIs need the iOS 27.1 SDK or later.

## Fold APIs: verified and assumed

Fold handling sits behind the `FoldStateService` protocol in `PocketPetCore`, so the logic can be tested with `MockFoldStateService` and a normal iPhone gets a clean fallback (`FoldPosture.unavailable`).

Names marked **verified** appear in Apple's own documentation or tech talk code samples. Names marked **assumed** are not confirmed, and need checking in Xcode before release.

| Name | Status | Source |
| --- | --- | --- |
| `View.onHingeChange(isEnabled:_:)` (SwiftUI) | verified, iOS 27.1 | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/), [DeviceHinge docs](https://developer.apple.com/documentation/swiftui/devicehinge) |
| `DeviceHingeContext.hinge` (nil on devices without a hinge) | verified | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) |
| `DeviceHinge.angle` (`Angle`) and `DeviceHinge.status` | verified | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) |
| `DeviceHinge.Status` cases `.closed`, `.partiallyOpen`, `.fullyOpen` | verified (`.partiallyOpen` in Apple sample code, all three in the docs); TODO to confirm against the SDK in Xcode | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/), [DeviceHinge docs](https://developer.apple.com/documentation/swiftui/devicehinge) |
| `UIHingeInteraction` (UIKit); note `UIHinge.angle` is in radians, unlike SwiftUI's `Angle` | verified (not used) | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, for example `reservedRegions(kind: .division, options: .includeInactive)` | verified | [Tech talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| `ArrangementView`, `.arrangementViewStyle(.split)` | verified (not used yet) | [Tech talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Outer display | There is **no** dedicated outer-display API. A closed iPhone Duo acts as a normal compact iPhone, so the glance is just the compact layout shown while the posture is `.closed`. (Scene accessories such as `CameraCaptureAccessory` exist, but they are for camera apps and are not used.) | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/), [Tech talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| `FoldPosture`, `FoldStateService`, `MockFoldStateService`, `HingeReading` | ours, not Apple APIs | `Sources/PocketPetCore/Fold/` |

Apple's tech talk advises using hinge data for live effects and the arrangement and reserved region APIs for layout. Hingeling follows that: the hinge drives the pet's scene (glance, home, stage), and layout inside each scene uses standard containers.

## Naming

Checked on 17 October 2026 with a web search of app stores and trademarks:

- "PocketPet" is an existing open source virtual companion app (pocketpet.app) and a pet care app (Pocket Pet Pte Ltd, Google Play).
- "Duo-Pet" is an existing iOS app.
- "Duo" is strongly associated with an existing education app's mascot, and "iPhone Duo" is Apple's product name.

"Hingeling" turned up no app, game or software trademark. It still needs a proper trademark search before App Store submission.

## Licence

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Justin Middler.
