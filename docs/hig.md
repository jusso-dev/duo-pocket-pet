# Human Interface Guidelines checklist

How Hingeling lines up with Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) and the iPhone Duo guidance in tech talks [111463](https://developer.apple.com/videos/play/tech-talks/111463/) and [111464](https://developer.apple.com/videos/play/tech-talks/111464/). Check it again when you add a screen.

## iPhone Duo safe zones

The Duo reserves three parts of the screen. Each one is read at runtime, never hard-coded, so a new model or a rotated screen still works.

| Region | What Apple says | What Hingeling does |
| --- | --- | --- |
| Safe area (status bar, home indicator, side bars) | Keep content inside it. On the Duo the system bars sit on the side, so the space isn't symmetric. | Every scene lays out inside the safe area. Only `RetroBackdrop` runs edge to edge. |
| Fold (`.division`) | Don't put controls or key content on the crease. | `FoldAwareSplit` puts the pet on one side and the controls on the other. Home asks with `.includeInactive`, so the split holds even when the phone lies flat. |
| Cameras (`.occlusion`) | The outer camera is always there. The inner camera only counts while it's on, and the UI should move aside. | `AvoidsOcclusion` pads the content away from any active camera region that reaches into it, on whichever edge is nearest. The backdrop stays put. The maths is `ReservedInsets` in the core package, with Linux tests. |

Folding doesn't jump between unrelated layouts. Closed shows the glance, open shows home, half folded shows the stage, and the pet and its meters look the same in all three.

## Accessibility

- Dynamic Type: text scales, and home scrolls and stacks its buttons at accessibility sizes.
- VoiceOver: each control has a label and hint, the pet and its meters read as single elements, and action results are announced.
- Reduce Motion: scene changes and the spotlight tilt are off.
- Increase Contrast: unlit LCD pixels and soft ink switch to full-strength ink (`RetroPalette.increasedContrast`). The base palettes already pass WCAG AA, and `RetroTests` checks both.
- Dark Mode: the LCD turns into a backlit screen.

## Controls

- Hit targets are at least 44 by 44 points. The keycaps are bigger, and the save banner's dismiss button gets a 44 point frame around its small icon.
- The Nearby sheet closes with the system Close button (`Button(role: .close)`), in the top leading corner, as sheets with nothing to confirm should.
- Haptics back up what the screen shows: a success tap when Feed, Clean, Play or Bedtime works, a warning when the pet refuses, and an impact on Cheer. They follow the system's haptics setting.

## Launch

The launch screen is the backdrop colour (`LaunchBackground`, light and dark), so opening the app doesn't flash white before the dusk sky appears.

## Privacy

Nearby play is off until the player turns it on. The local network prompt explains what is shared: the pet's name, life stage and mood, nothing else.
