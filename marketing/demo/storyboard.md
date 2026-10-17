# Demo clip storyboard

**Prepared only. Do not post or schedule.** Justin decides when, and whether, it goes out.

- Length: 15 seconds
- Frame: 1080 by 1920 (portrait), 30 fps
- Captions: burned in and readable with the sound off
- Audio: none. If sound is added later, use only original or properly licensed audio. No third-party music without a licence.

## Shots

| Time | Shot | On screen | Caption |
| --- | --- | --- | --- |
| 0 to 3 s | Closed phone | The compact outer-screen glance. Bip is asleep, with a slow two-frame snore and drifting "z"s. | Closed, Bip naps on the outer screen |
| 3 to 7 s | Open it | The inner screen with Bip on one side of the fold and the meters and buttons on the other. At about 4.2 s, Feed is tapped, the feed reaction plays and Fullness rises. | Open it up to feed, clean and play |
| 7 to 11 s | Half fold | The top half is a dark stage with a spotlight that sways as the hinge moves, and Bip dances. The bottom half shows the Cheer button. | Half fold it and Bip puts on a show |
| 11 to 13.5 s | Close it | Back to the glance. Bip curls up asleep. | Close it, and Bip curls up again |
| 13.5 to 15 s | End card | Bip, joyful, over the name. | **Hingeling**, a pocket pet that lives in the fold |

## The animatic

`hingeling-demo-animatic.mp4` is a timing and caption draft, rendered by `scripts/demo-animatic.py` from the project's own sprite art (`docs/art/contact-sheet.png`). It draws generic rounded rectangles, not a real phone, so it carries no device frames or Apple marks. The font is DejaVu Sans Bold, whose licence allows this use.

To regenerate it (needs Pillow and ffmpeg):

```sh
scripts/demo-animatic.py
```

## Capturing the real clip

The final clip should be the real app, recorded on an iPhone Duo simulator or device, cut to the same timings, with the same captions burned in.

1. Launch with `-mockFold` to play the closed, open, half fold, closed script. Use `-pet content,young` for a predictable pet.
2. Record with `xcrun simctl io booted recordVideo demo-raw.mov`.
3. Cut to 15 seconds, scale to 1080 by 1920, and burn in the captions above with the same font.

## Checklist before Justin reviews

- [x] 15 seconds or less (the animatic is exactly 15.0 s)
- [x] 1080 by 1920
- [x] Captions burned in and readable with the sound off
- [x] Alt text written (see `caption-draft.md`)
- [x] Original assets only, and no music
- [x] Nothing posted or scheduled
