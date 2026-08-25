# Flexi Run

A 2D endless runner plus shape-matching puzzle for kids aged 6 to 10.

You follow a cute slime from behind as it runs up a path into a storybook
landscape. Brick barriers come down the path toward you with a shape-shaped
hole punched through them, over the left, middle or right track. Get the slime
into the right track wearing the right shape and it passes cleanly through;
get either one wrong and it slams into the bricks and loses a life.

Three shapes, three tracks, three lives. Every five clean passes earns a shield
that eats the next wall whatever shape it is.

## Run it

```bash
flutter pub get
flutter run                 # landscape only, on a device or emulator
```

### Controls

| | Shape | Lane |
|---|---|---|
| Touch | the three buttons, or tap a third of the screen | the corner arrows, or swipe sideways |
| Keyboard | `1` `2` `3` | `←` `→` |

`space` starts a run, so the game is playable on desktop without a touchscreen.
Tap-a-third and swipe both come from the same layer and do not fight: a gesture
that moves is a lane change, one that does not is a shape.

## Check it

```bash
flutter analyze
flutter test
```

`test/pass_through_test.dart` renders real frames and samples pixels to prove
the core visual rule: the bricks occlude the runner and only the part inside
the hole stays visible.

## Layout

```
lib/
  main.dart                 orientation lock, GameWidget, overlays, lifecycle
  core/                     constants, shapes, audio, prefs, placeholder art
  game/                     FlameGame, state machine, difficulty, projection
  components/               world components (road, scenery, player, wall, fx)
  ui/                       Flutter overlays (HUD, shape pad, menu, game over)
```

Every tunable number lives in `lib/core/constants.dart`. The difficulty curve is
pure functions in `lib/game/difficulty.dart`; both it and the perspective in
`lib/game/projection.dart` are unit tested.

## How the perspective works

Nothing in the world has an x and a y of its own. It has a depth `z`, where 0
is the runner's own plane and larger is further up the path, and
`lib/game/projection.dart` turns that into screen space:

- `scaleAt(z)` — how big it looks, `kFocal / (kFocal + z)`
- `laneXAt(z)` / `groundYAt(z)` — where the path is at that depth
- `depthPriority(z)` — what draws over what

That last one carries the whole illusion. A wall still ahead of the runner
draws *behind* it; the moment it crosses the runner's plane it draws *in
front*. So the bricks swallow the body and only what is inside the hole
survives. `test/projection_test.dart` pins that flip down.

To make the perspective more or less aggressive, change `kFocal`. To move the
camera, change `kVanishX`, `kNearLaneX` and `kNearGroundY`.

## Art and audio

The game ships with placeholder art generated in code by
`lib/core/placeholder_art.dart`, lit from one direction so the pieces read as
one scene. Everything already goes through a `Sprite`, so swapping in
commissioned PNGs means replacing `buildPlaceholderArt()` with a loader and
touching nothing else.

The art it would replace, into `assets/images/`:

```
bg/       sky, clouds, hills, trees, bushes, ground
player/   one slime per shape, plus the shield ring
walls/    one wall per shape per lane, hole genuinely transparent
ui/       hearts and the three shape buttons
```

Two rules for the wall art: the hole must be a real transparent opening, not a
painted one, and its centre must land on `kHoleLocalY` so it lines up with the
runner's body when the wall's base sits on the ground.

The sound effects and music loop in `assets/audio/` are placeholders too,
synthesised as WAV by:

```bash
dart run tool/generate_placeholder_audio.dart
```

To use the commissioned audio instead, drop the files in and change the six
filenames at the top of `lib/core/audio.dart`. Every call in that class is
guarded, so a missing or unplayable clip degrades to silence rather than
interrupting a run.

## Tuning for playtests

Only two numbers should be touched after playtesting with an actual child:

- `kGapStart` - seconds of thinking time between walls (1.8 for age six)
- `kSpeedStart` - starting world speed

Both are in `lib/core/constants.dart`.

The difficulty curve works in one way and deliberately not the other:

- **The speed never changes.** It is held flat at 265. A wall always takes
  about four and a half seconds to arrive, so the timing a child learns in the
  first minute is the timing for the whole run. Earlier versions ramped the
  speed and it made the game unplayable well before a six year old had
  finished learning the shapes.
- **Only the spacing tightens.** `kGapDecay` closes the gap between walls from
  1.8s to 1.15s over `kRampScore`, which is 500 - fifty walls, two or three
  minutes of play. Past that the run holds its pace and becomes a stamina
  test rather than getting harder.

`kRampScore` is the one knob for pace, and `kGapDecay` is derived from it. To
put a speed ramp back, raise `kSpeedMax` above `kSpeedStart`; `kSpeedPerPoint`
is derived the same way and will climb to it over the same score.

Two things to check if you change the speed:

- `kRunHz`, the leg cycle. It is a fixed rate rather than one driven by the
  world speed, so it has to be moved to match or the runner sprints on the spot.
- `kMinWallSeparationZ`. At 265 with the gap at its floor, two walls are 305
  apart against a 300 minimum, so there is not much room to slow down further
  without walls arriving stacked. `difficulty_test.dart` fails if you cross it.
