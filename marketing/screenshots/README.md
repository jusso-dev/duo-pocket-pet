# App Store screenshots

Prepared only. Nothing here has been uploaded to App Store Connect or submitted.

## Shot list

| # | File | Scene | Launch arguments | Caption |
| --- | --- | --- | --- | --- |
| 1 | `1-glance.jpg` | Glance on the outer screen, phone closed | `-fold closed -pet asleep,young` | Close your phone and Bip curls up for a nap. |
| 2 | `2-home-feed.jpg` | Home on the inner screen, mid-feed | `-fold open -pet hungry,young`, then tap Feed | Open it up to feed, clean and play. |
| 3 | `3-stage.jpg` | Half-fold stage | `-fold half:110 -pet joyful,grown` | Half fold it and Bip puts on a show. |
| 4 | `4-standard-home.jpg` | Standard iPhone home | `-fold unavailable -pet content,young` | No fold? A bedtime button does the same job. |
| 5 | `5-elder.jpg` | A grown-up pet | `-fold open -pet joyful,elder,Old Bip` | Look after Bip and watch it grow up. |

Captions are in Australian English. They describe what Hingeling does and make no claim of any link with Apple. If a caption names a device, use "iPhone" or "iPhone Duo" as plain product names only, never Apple logos or marks.

## Sizes

Checked against [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) on 17 October 2026. **Check again on the day you upload**, because the list changes.

| Display | Portrait (px) | Status on 17 October 2026 | Simulator to use |
| --- | --- | --- | --- |
| iPhone with Dynamic Island, 6.3" (medium) | 1206 × 2622 or 1179 × 2556 | Required, at least one screenshot | iPhone 18 Pro |
| iPhone with Dynamic Island, 6.9" (large) | 1320 × 2868, 1290 × 2796 or 1260 × 2736 | Optional. If it's left out, a Face ID (large) set is required instead | iPhone 18 Pro Max |
| iPhone Duo, outer display | 1398 × 2034 | Optional now. Required from April 2027 for apps built with the iOS 27.1 SDK or later | iPhone Duo, closed |
| iPhone Duo, inner display | 2007 × 2853 | Same as the outer display | iPhone Duo, open |

Files must be JPEG or PNG with no alpha channel. The script exports JPEG, which has none.

For iPhone Duo, take shot 1 with the simulator showing the outer display, and shots 2, 3 and 5 on the inner display. Shot 4 is for standard iPhones only. The script prints each file's pixel size, so check every one against this table before uploading.

## No frames or marks

The shots are plain screen captures: no device frames, Apple logos or other Apple marks. If frames are ever added, they must follow Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).

## Regenerating

On a Mac with Xcode (iOS 27.1 SDK or later) and `xcodegen`:

```sh
scripts/screenshots.sh                                   # iPhone 18 Pro and iPhone 18 Pro Max
DUO_SIM="iPhone Duo" scripts/screenshots.sh              # adds the Duo
scripts/screenshots.sh "iPhone 17 Pro"                   # any simulators you name
```

The script:

1. Generates the Xcode project.
2. Sets a tidy status bar on each simulator.
3. Runs `ScreenshotTests` with `TEST_RUNNER_HINGELING_SCREENSHOTS=1`.
4. Exports the attachments to `marketing/screenshots/out/<simulator>/` as JPEGs.

The `out/` folder is git-ignored.

`ScreenshotTests` is skipped in normal test runs and in CI.
