# hand_tap.json

The pointing hand used by the coach-mark tutorial.

## Provenance

| | |
| --- | --- |
| Title | hand_tap_01 (the composition's own name) |
| Author | **[UNKNOWN - fill this in]** |
| Source URL | **[UNKNOWN - fill this in]** |
| Licence | **[UNCONFIRMED - see below]** |
| Downloaded | 2026-10-05, supplied by the project owner |

**The licence has not been checked, and this repository is public.** Free Lottie
animations are commonly licensed for use *inside* a product but not for
redistribution as an asset - which is exactly what committing the JSON here
does. Confirm the terms before this ships, or replace the file with one whose
licence allows redistribution.

## What a replacement has to match

The code depends on this file in two ways that break silently if it is swapped:
the colour delegates key on **names**, and the hand is placed by a **measured**
fingertip. `test/hand_art_test.dart` re-measures and will fail on drift, but it
cannot tell you what to change.

| | |
| --- | --- |
| Canvas | 600 x 600 |
| Frame rate | 25 |
| Frames | 0 .. 41 (Lottie reports `endFrame` 40.99) |
| Duration | 1.64 s |
| Resting frame | 0 - still, and before the ripples exist |
| Measured fingertip | (0.3979, 0.2958) as a fraction of the box |

Layer and group names the delegates key on:

| Delegate | Path |
| --- | --- |
| Hand fill | `hand_tap_01 Outlines` / `Group 1` / `Fill 1` |
| Hand outline | `hand_tap_01 Outlines` / `Group 2` / `Stroke 1` |
| Ripples | `Shape Layer 3` / `**`, `Shape Layer 4` / `**` |

## Structure, and what was *not* done to it

Two things go wrong with almost every free hand-tap animation. Neither is
present here, so **the JSON is unmodified** - worth knowing, because a future
edit should not assume it has already been cleaned up.

- **Not hollow.** The fill group holds exactly one closed path, so the
  two-contour non-zero-fill trap - where opposite windings fill only the band
  between them and leave the middle unpainted - does not apply. No contour was
  deleted.
- **The outline is already in front.** `Group 2` (the stroke) sits at index 0
  and `Group 1` (the fill) at index 1; earlier groups paint on top, so the dark
  edge is already over the fill. No groups were reordered.

The hand is drawn black in the file. It is **white with a near-black outline at
runtime**, through `HandArt.delegates()` - no colour was edited into the JSON,
so the palette stays where the rest of the app can see it.

Two further details of the composition, which matter if the animation is ever
retimed:

- The tap travels *up and left*: the parent null `GRP 2` moves from
  `[329, 329]` to `[300, 271]` between frames 0 and 7, holds to frame 12, and
  returns by frame 20. Frames 20-41 are the same pose as frame 0.
- The ripples are two circles on **inverted alpha mattes** of the hand, so they
  are drawn only outside its silhouette. They start at frame 7. This is why the
  fingertip is measured at frame 0: from frame 7 on, the topmost ink in the box
  is a ripple ring rather than the finger, and measuring there gives an answer
  that is wrong by about a fifth of the box.
