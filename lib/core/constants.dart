import 'dart:ui';

// Every tunable number in the game lives here. Nothing else in the codebase
// should contain a magic number.
//
// The world is drawn from behind the runner: the path recedes to a horizon,
// and walls start small at the far end and rush toward the camera. Positions
// are therefore given as a depth `z` (0 is the runner's own plane, larger is
// further away) plus a perspective projection, rather than as an x on a
// side-scrolling plane.

// ---------------------------------------------------------------------------
// Virtual screen
// ---------------------------------------------------------------------------

const kWorldW = 1280.0;
const kWorldH = 720.0;

// ---------------------------------------------------------------------------
// Camera and perspective
// ---------------------------------------------------------------------------

/// The path recedes diagonally to the upper right, so the vanishing point sits
/// right of centre and the runner sits left of it. That is what gives the
/// three quarter view: you see the runner's back as it heads up the path.
const kVanishX = 812.0;

/// Screen x of the lane at the runner's own depth.
const kNearLaneX = 430.0;

/// Where the ground meets the sky.
const kHorizonY = 300.0;

/// Screen y of the ground at the runner's own depth.
///
/// Kept well above the bottom of the frame: the strip of near path below the
/// runner is where the shape buttons sit, so the runner is not hidden under
/// its own controls.
const kNearGroundY = 520.0;

/// World point the camera is centred on.
///
/// Below the middle of the world on purpose: it aims the view down the path,
/// which lifts the runner clear of the controls along the bottom of the screen
/// and trades empty sky for usable ground.
const kCameraCentreY = 430.0;

/// Focal length of the projection: scale = kFocal / (kFocal + z).
///
/// Smaller values make things grow harder as they arrive, which is what sells
/// the depth. This is the main dial for how aggressive the perspective feels.
const kFocal = 260.0;

// ---------------------------------------------------------------------------
// Depth
// ---------------------------------------------------------------------------

/// Walls appear at this depth, small, near the horizon.
const kWallSpawnZ = 1300.0;

/// The runner's plane. A wall crossing this is a hit or a pass.
const kWallHitZ = 0.0;

/// Once a wall is this far past the camera it is gone.
const kWallCullZ = -150.0;

/// Below this the projection blows up, so nothing is drawn nearer.
const kMinDrawZ = -170.0;

// ---------------------------------------------------------------------------
// Runner, drawn at z = 0
// ---------------------------------------------------------------------------

const kPlayerBodySize = 190.0;
const kPlayerHalf = kPlayerBodySize / 2;

const kLegLength = 46.0;
const kLegW = 34.0;
const kLegSpread = 30.0;
const kArmW = 40.0;
const kArmH = 24.0;
const kArmOverlap = 22.0;

/// Feet on the ground, so the runner is never floating.
const kPlayerFeetY = kNearGroundY;

// ---------------------------------------------------------------------------
// Lanes
// ---------------------------------------------------------------------------

/// Sideways gap between the three tracks, in world units at z = 0.
///
/// Wide enough that the runner clears its neighbours, narrow enough that all
/// three holes fit inside a wall.
const kLaneOffset = 260.0;

/// How long the runner takes to slide between lanes. The lane itself changes
/// instantly on input; this is only how long the slide looks like it takes.
const kLaneShiftSeconds = 0.13;

/// A swipe shorter than this is treated as a tap, not a lane change.
const kSwipeThreshold = 24.0;

/// Body centre. The wall holes line up with this height.
const kPlayerCentreY = kNearGroundY - kLegLength - kPlayerHalf;

// ---------------------------------------------------------------------------
// Walls, sized at z = 0
// ---------------------------------------------------------------------------

/// A wide, chunky barrier across the path, so the hole is the only way
/// through. These are its dimensions at z = 0, where it is at its biggest.
const kWallW = 1150.0;
const kWallH = 470.0;

/// Deliberately larger than the runner.
const kHoleHalf = 118.0;

const kHoleLocalX = kWallW / 2;

/// Hole centre in wall-local coordinates. With the wall base on the ground at
/// its own depth, this is what keeps the hole on the runner's centre height.
const kHoleLocalY = kWallH - (kNearGroundY - kPlayerCentreY);

// ---------------------------------------------------------------------------
// Speed and spacing (section 4). Speeds are depth units per second.
// ---------------------------------------------------------------------------

/// Score at which the game stops getting harder. The gap reaches its floor
/// here and holds; past it the run is a stamina test at a fixed pace.
///
/// This is the single knob for how quickly the game ramps. At
/// [kScorePerWall] a wall, 500 is fifty walls, two or three minutes of play.
/// Section 16 put it at 200, which was twenty walls: a child was at the
/// ceiling before they had finished learning the shapes.
const kRampScore = 500.0;

// Held flat at 265, rather than the 350 to 620 ramp in section 16. The run
// never speeds up: whatever the score, a wall takes the same four and a half
// seconds to arrive, so a child who has learned the timing keeps it.
//
// The game still gets harder with the score, but only through [kGapDecay] -
// walls arrive closer together, not faster. To put a speed ramp back, raise
// [kSpeedMax] above [kSpeedStart] and it will climb to it over [kRampScore].
const kSpeedStart = 265.0;
const kSpeedMax = 265.0;

const kGapStart = 1.8;
const kGapMin = 1.15;

// Derived, so the two curves cannot drift apart: both reach their limit at
// [kRampScore] and neither can be retuned without the other following.
const kSpeedPerPoint = (kSpeedMax - kSpeedStart) / kRampScore;
const kGapDecay = (kGapStart - kGapMin) / kRampScore;

/// Two walls must never arrive stacked on top of each other.
///
/// At a fixed 265 this is the real floor under [kHardGapMin]: 265 x 1.0 leaves
/// 265 units between walls, so the separation rule is what decides how tight
/// the hardest level is allowed to get, not the gap number on its own.
const kMinWallSeparationZ = 260.0;

// ---------------------------------------------------------------------------
// Levels
//
// The speed is 265 on all three. A child who has learned the timing on Easy
// should not have to learn it again to move up, so what changes is how close
// together the walls arrive, how much else there is to think about, and how
// much room there is to get it wrong.
//
// Medium is the game exactly as it was tuned before levels existed.
// ---------------------------------------------------------------------------

/// Easy opens every wall on the middle track.
///
/// The biggest single change of the three, and not a number. Normally a child
/// solves two things at once - which shape, and which track - and at six that
/// is the difference between playing and being played at. On Easy the arrows
/// still work but are never needed, so it is a pure shape-matching game.
const kEasyGapStart = 2.4;
const kEasyGapMin = 1.9;
const kEasyRampScore = 700.0;
const kEasyLives = 5;
const kEasyShieldEvery = 3;
const kEasyForgiveSeconds = 0.25;

const kMediumGapStart = kGapStart;
const kMediumGapMin = kGapMin;
const kMediumRampScore = kRampScore;
const kMediumLives = kLives;
const kMediumShieldEvery = kShieldEveryPasses;
const kMediumForgiveSeconds = kForgiveSeconds;

/// Hard is tighter, not meaner: it keeps three lives and the same penalty. A
/// life lost to something a child did not understand is what makes them stop
/// playing, so the squeeze is on the reaction window instead.
const kHardGapStart = 1.5;
const kHardGapMin = 1.0;
const kHardRampScore = 300.0;
const kHardLives = 3;
const kHardShieldEvery = 8;
const kHardForgiveSeconds = 0.08;

/// The world drifts forward behind the title.
const kMenuSpeed = 90.0;

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

const kLives = 3;
const kScorePerWall = 10;
const kShieldEveryPasses = 5;
const kInvulnSeconds = 0.9;

/// Late-tap forgiveness: a mismatched wall holds its verdict open this long.
const kForgiveSeconds = 0.12;

const kHitFreezeSeconds = 0.35;
const kFirstSpawnDelay = 0.0;

// ---------------------------------------------------------------------------
// Runner feel
// ---------------------------------------------------------------------------

const kPopScale = 1.15;
const kPopSeconds = 0.15;

const kSqueezeX = 0.82;
const kSqueezeY = 1.06;
const kSqueezeSeconds = 0.18;

// ---------------------------------------------------------------------------
// Tuck.
//
// The runner is wider than its own body: the feet hang 141 below its centre
// and the hands reach 113 out from it, against a hole of 118. Going through,
// the parts outside the opening are behind brick - correct, but it reads as
// the runner losing its hands and feet.
//
// The hole cannot simply be made bigger. A star's inner corners sit at under
// half its radius, so a star wide enough to swallow the limbs would not fit
// on the wall at all. So the runner pulls itself in instead: limbs retract
// behind the body, which is the same shape as the hole and therefore always
// fits, and come back out the other side.
// ---------------------------------------------------------------------------

/// Held long enough to cover the wall sweeping past and fading out, so no
/// frame ever shows a limb sliced off by brick.
const kTuckSeconds = 0.44;
const kTuckRiseSeconds = 0.07;
const kTuckFallSeconds = 0.14;

/// How far the legs draw up into the body, and how far the arms draw in.
const kLegTuckRise = 48.0;
const kLegTuckSpread = 0.35;
const kArmTuckIn = 36.0;
const kArmTuckScale = 0.65;

const kBlinkHz = 18.0;
const kBlinkDimOpacity = 0.25;

// ---------------------------------------------------------------------------
// Run cycle.
//
// One cycle is two steps. Everything the runner does is phase locked to it:
// the body drops as a foot lands and rides up as the legs pass underneath,
// squashing on the way down and stretching on the way up, while the planted
// foot stays on the ground and the body travels over it.
//
// That last part is the whole trick. A body that bobs on its own, with legs
// swinging on a separate clock, reads as floating no matter how fast the legs
// move. Weight going into the ground and coming back out is what reads as
// running.
//
// Not driven by the world speed, so it has to be set to suit it: too fast and
// the runner looks like it is sprinting on the spot.
// ---------------------------------------------------------------------------

const kRunHz = 2.5;

/// How far the body rides up and down over one step.
const kRunBobPixels = 15.0;

/// Compression as the weight lands, and the matching stretch as it lifts.
const kRunSquash = 0.055;

/// Side to side sway. Small, but from behind it is most of what stops the
/// runner looking like it is on rails.
const kRunSwayPixels = 7.0;

const kLegSwing = 22.0;
const kLegLift = 18.0;

/// A planted leg is stretched to reach the ground, never shorter than this.
const kLegMinLength = 14.0;

const kArmSwing = 0.42;
const kArmLift = 9.0;

const kRecoilPixels = 18.0;
const kRecoilSeconds = 0.3;

const kShieldRingScale = 1.34;
const kShieldRingPulseSeconds = 0.45;
const kShieldRingPulseScale = 1.25;
const kShieldIdleOpacity = 0.85;
const kShieldTintOpacity = 0.35;

// ---------------------------------------------------------------------------
// Camera shake
// ---------------------------------------------------------------------------

const kShakeSmash = 10.0;
const kShakeHit = 15.0;
const kShakeDecay = 45.0;
const kShakeHzX = 34.0;
const kShakeHzY = 27.0;

// ---------------------------------------------------------------------------
// Render order. Lower number draws first.
//
// A wall ahead of the runner is behind it and draws first; once it crosses the
// runner's plane it is between the runner and the camera and draws in front.
// That flip is what produces the pass-through: bricks occlude the body and
// only the part inside the hole stays visible.
// ---------------------------------------------------------------------------

const kPrioSky = 0;
const kPrioClouds = 1;
const kPrioHills = 2;
const kPrioRoad = 3;

/// Depth-sorted band for anything still ahead of the runner.
const kPrioFarBase = 20;
const kPrioFarSpan = 200;

const kPrioDust = 400;
const kPrioPlayer = 500;

/// Depth-sorted band for anything that has passed the runner.
const kPrioNearBase = 600;
const kPrioNearSpan = 50;

const kPrioBurst = 800;

/// Depth quantisation for the priority bands.
const kDepthPriorityStep = 8.0;

// ---------------------------------------------------------------------------
// Road
// ---------------------------------------------------------------------------

/// Hills band, sitting on the horizon.
const kHillsH = 200.0;
const kHillsOverlap = 26.0;

const kRoadHalfWidth = 430.0;
const kRoadEdgeWidth = 16.0;
const kStripeSpacing = 150.0;
const kStripeDuty = 0.45;

/// Rungs drawn per frame. They compress toward the horizon, so beyond this
/// they stop being distinguishable.
const kRungCount = 26;

// ---------------------------------------------------------------------------
// Ground cover
//
// A flat green field is the single clearest tell that a scene is painted
// rather than travelled through: it never moves, so the eye reads it as
// wallpaper behind a scrolling path. These are patches of lighter and darker
// grass, projected and scrolled with everything else, so the field rushes past
// at the same rate the path does.
// ---------------------------------------------------------------------------

const kGroundPatchCount = 84;

/// Seeded, so the field is laid out the same way every run.
const kGroundSeed = 23;

/// Depth the patch field wraps over. Larger than the draw distance, so a patch
/// is recycled well out of sight.
const kGroundPatchSpanZ = 2600.0;

/// Patches sit off the path, from just past its edge out to the verge.
const kGroundPatchNear = 452.0;
const kGroundPatchFar = 1600.0;

const kGroundPatchW = 260.0;
const kGroundPatchH = 54.0;

/// How much each patch varies from that size, as a fraction.
const kGroundPatchJitter = 0.6;

/// Blurred, so they read as mottling rather than as lily pads on a lawn. A
/// hard edged ellipse on grass is a shape; a soft one is texture.
///
/// Baked into a sprite once, never applied at draw time - see
/// [paintGrassPatch]. Blurring per frame was costing the game its frame rate.
const kGroundPatchBlur = 12.0;

/// Room round the blotch for the blur to fall off in, in blur radii.
const kGroundPatchBlurPad = 3.0;

/// Patches shrink away over this stretch rather than popping out of existence,
/// and are not drawn at all beyond the far end of it.
const kGroundPatchFadeZ = 900.0;
const kGroundPatchCullZ = 1600.0;

/// Blades along the edge of the path, so the two surfaces meet in a fringe
/// rather than a drawn line.
const kVergeTuftCount = 120;
const kVergeTuftSpanZ = 900.0;
const kVergeTuftBand = 76.0;
const kVergeBlades = 3;
const kVergeBladeH = 26.0;
const kVergeBladeW = 2.2;
const kVergeBladeLean = 13.0;

/// Perspective would make a blade at the camera's feet taller than the runner.
/// True, and unreadable, so the near end of the scale is capped.
const kVergeMaxScale = 1.5;

/// Nearest blades are the only ones big enough to read; past this they are
/// sub-pixel noise and cost more than they show.
const kVergeTuftCullZ = 620.0;

/// Blades grow out of the ground over this last stretch rather than appearing
/// at full height, so nothing pops into being at the cull distance.
const kVergeTuftGrowZ = 260.0;

/// Clumps are stamped from a few pre-drawn images rather than built as paths
/// every frame. The box one is drawn in, and how many different ones there are.
const kVergeTuftW = 40.0;
const kVergeTuftH = 34.0;
const kVergeTuftVariants = 3;
const kVergeSeed = 47;

// ---------------------------------------------------------------------------
// Roadside scenery
// ---------------------------------------------------------------------------

const kSceneryCount = 24;
const kScenerySpawnZ = 2400.0;
const kSceneryLateral = 520.0;
const kSceneryLateralJitter = 240.0;
const kSceneryBaseSize = 300.0;

/// One row per tree: canopy width, canopy height, trunk height and lean, all
/// as fractions of the sprite box.
///
/// Three silhouettes rather than one. A verge lined with the same tree over
/// and over is the other half of why scenery reads as wallpaper.
const kTreeShapes = <(double, double, double, double)>[
  (0.74, 0.60, 0.34, 0.015), // broad, round headed
  (0.44, 0.80, 0.26, -0.03), // tall and narrow
  (0.86, 0.44, 0.24, 0.045), // low and spreading
];

/// Same idea for bushes: one round, one low and wide.
const kBushShapes = <(double, double)>[
  (0.52, 0.44),
  (0.72, 0.30),
];

/// Leaf clusters per canopy. The rim ones are what make the silhouette
/// scalloped instead of a circle; the core ones fill the mass behind them.
const kTreeRimClusters = 18;
const kTreeCoreClusters = 9;
const kTreeRimRadius = 0.20;
const kTreeCoreRadius = 0.30;

/// Seeds, so every build draws the same trees.
const kTreeSeed = 17;
const kBushSeed = 31;

// ---------------------------------------------------------------------------
// Haze
//
// Air between the camera and a distant object washes it toward the colour of
// the sky. Without it a far tree is the same tree, only smaller, and the scene
// has no air in it at all.
// ---------------------------------------------------------------------------

const kHazeTintColor = Color(0xFFCFE6F0);
const kSceneryHazeStartZ = 260.0;
const kSceneryHazeFullZ = 2200.0;

/// How far the wash goes at the horizon. Full white would erase the scenery.
const kSceneryHazeMax = 0.66;

/// Quantised so the filters can be built once instead of every frame.
const kSceneryHazeSteps = 14;

// ---------------------------------------------------------------------------
// Dust, sparkles, shards
// ---------------------------------------------------------------------------

const kDustInterval = 0.09;
const kDustLifespan = 0.55;
const kDustRadius = 16.0;
const kDustSpread = 90.0;
const kDustRise = 30.0;

/// Fraction of the world speed the puffs inherit toward the camera.
const kDustSpeedShare = 0.35;

const kSparkleCount = 22;
const kSparkleLifespan = 0.6;
const kSparkleSpeed = 340.0;
const kSparkleRadius = 11.0;

const kShardCount = 18;
const kShardLifespan = 0.9;
const kShardSpeed = 420.0;
const kShardGravity = 1100.0;
const kShardSize = 54.0;

// ---------------------------------------------------------------------------
// Shape geometry
// ---------------------------------------------------------------------------

const kSquareCornerRatio = 0.26;
const kStarInnerRatio = 0.47;
const kStarPoints = 5;

const kPickBaseWeight = 1.0;
const kPickRecentBias = 0.4;

// ---------------------------------------------------------------------------
// Placeholder art. Generated in code until the real PNGs land.
// ---------------------------------------------------------------------------

const kArtScaleSprite = 2.0;
const kArtScaleLayer = 1.0;

/// Walls are huge at z = 0, so they are authored below their display size and
/// scaled up. Raising this costs memory fast.
const kArtScaleWall = 0.6;

const kBrickRowH = 84.0;
const kBrickColW = 146.0;
const kMortarW = 11.0;
const kHoleRimWidth = 10.0;
const kWallEdgeWidth = 10.0;

const kSlimeInset = 0.94;
const kSlimeStroke = 6.0;

/// The radius the runner's shading is tuned at.
///
/// Outlines, rims and gloss blurs are absolute numbers picked against this. The
/// app icon draws the same body several times larger, so it scales them by how
/// far it is from here - which keeps the icon and the runner identical at the
/// runner's own size rather than merely similar.
const kSlimeRefRadius = kPlayerHalf * kSlimeInset;
const kBackTuftRatio = 0.3;

const kShieldRingWidth = 11.0;
const kShardRadius = 8.0;

const kSkyTop = Color(0xFF8FD8F5);
const kSkyBottom = Color(0xFFDFF3FF);
const kCloudColor = Color(0xFFFFFFFF);
// Distant hills go blue, not green. That shift is the whole reason a range of
// hills reads as miles away rather than as a green shape behind the trees.
const kHillsFarColor = Color(0xFFB2D2CB);
const kHillsMidColor = Color(0xFF83BC90);
const kCastleColor = Color(0xFFCBB8E8);
const kCastleRoofColor = Color(0xFF8A6FC4);
const kTreeTrunkColor = Color(0xFF8A6242);
const kTreeLeafColor = Color(0xFF4B9450);
const kGrassColor = Color(0xFF64C46E);
const kGrassDarkColor = Color(0xFF4FAE5B);
const kPathColor = Color(0xFFE0C594);
const kPathDarkColor = Color(0xFFCBA871);
const kPathEdgeColor = Color(0xFFB9995E);
const kBushColor = Color(0xFF3C8E51);
const kSlimeColor = Color(0xFF7FD8F7);
const kSlimeDarkColor = Color(0xFF3EA6DC);
const kSlimeEyeColor = Color(0xFF20323C);
const kSlimeFootColor = Color(0xFF2E86C8);
const kSlimeShineColor = Color(0xB3FFFFFF);
const kShieldColor = Color(0xFF5BE8C8);
const kBrickColor = Color(0xFFC4644E);
const kBrickDarkColor = Color(0xFF9C4838);
const kMortarColor = Color(0xFFE8D9C8);
const kHoleRimColor = Color(0xFF6E2E22);
const kDustColor = Color(0xFFE6D6BC);
const kSparkleColor = Color(0xFFFFE27A);

// ---------------------------------------------------------------------------
// Coins.
//
// Laid in a short trail down the lane the next wall's hole is over, so they
// are not a distraction from the wall but a breadcrumb toward it: follow the
// gold and you are already standing in the right track when the wall arrives.
// A child who cannot yet read the hole still ends up in the right place.
//
// They are counted separately from the score on purpose. The score drives the
// difficulty ramp, so paying score for coins would tighten the wall spacing
// several times faster than it is tuned for.
// ---------------------------------------------------------------------------

/// How many rows in a trail, and how far apart in depth.
const kCoinsPerTrail = 4;
const kCoinSpacingZ = 95.0;

/// How many of those rows carry a coin in every track rather than only in the
/// one the hole is over.
///
/// The rows that arrive first are spread across all three, so there is gold to
/// chase wherever the runner happens to be standing. The last rows before the
/// wall narrow to the hole's own track, so the trail still ends by walking the
/// runner into the right place.
const kCoinSpreadRows = 2;

/// Where the trail starts relative to its wall. Negative is nearer the runner,
/// so the coins arrive first and the wall follows.
const kCoinLeadZ = -120.0;

/// Coin size at the runner's own plane.
const kCoinSize = 72.0;

/// Draw distance.
///
/// A trail has to be *laid* far up the path - it lives in the gap between one
/// wall and the next, or it would stop leading to the right one - but at that
/// range each coin is a few pixels of glitter on the horizon, which reads as
/// noise. They stay invisible beyond [kCoinAppearZ] and fade up to solid by
/// [kCoinSolidZ], so they arrive into view at a size worth looking at.
const kCoinAppearZ = 840.0;
const kCoinSolidZ = 620.0;

/// Height above the ground the trail floats at, so coins sit at chest height
/// rather than being hidden under the runner's feet.
const kCoinRiseY = 96.0;

/// A coin is taken if the runner is in its lane when it arrives.
const kCoinCatchZ = 0.0;

/// Turns per second. Purely cosmetic, but a still coin looks like a sticker.
const kCoinSpinHz = 0.55;

/// How narrow the coin gets edge on. Never zero, or it vanishes entirely.
const kCoinEdgeScale = 0.16;

/// How long a taken coin takes to rise and fade.
const kCoinCollectSeconds = 0.32;

const kCoinFace = Color(0xFFF7C948);
const kCoinLight = Color(0xFFFFE9A0);
const kCoinDeep = Color(0xFFC98A15);
const kCoinRim = Color(0xFFE0A21F);
const kCoinShine = Color(0xCCFFFFFF);

// ---------------------------------------------------------------------------
// Light and shading.
//
// One light for the whole game, high and to the left. Every form is shaded
// from it, which is most of what separates a drawing that reads as an object
// from one that reads as a coloured shape. Move [kLightOffsetX] and
// [kLightOffsetY] and the whole scene relights together.
// ---------------------------------------------------------------------------

/// Where the highlight sits on a round form, as a fraction of its radius.
const kLightOffsetX = -0.34;
const kLightOffsetY = -0.42;

/// How far the lit falloff spreads. Over 1 keeps the terminator soft rather
/// than a hard edge between lit and unlit.
const kLightSpread = 1.30;

/// The shadow a body casts on the ground it is standing on. Without this
/// nothing looks like it is touching the floor.
const kContactShadowColor = Color(0x59123018);
const kContactShadowBlur = 12.0;
const kContactShadowWidth = 0.84;
const kContactShadowHeight = 0.17;

/// How much the contact shadow shrinks and fades as the runner bobs up.
const kShadowLiftScale = 0.16;
const kShadowLiftFade = 0.28;

// The runner is jelly: light passes through it, so it is pale in the middle
// where it is thin and saturated at the edges where you are looking through
// more of it. That inversion - dark rim, bright core - is what separates
// something translucent from something solid, and it is most of what makes
// the reference character read as jelly rather than as a coloured ball.

const kSlimeLightColor = Color(0xFFDFF6FF);
const kSlimeMidColor = Color(0xFF7FD8F7);
const kSlimeDeepColor = Color(0xFF2E9BD6);
const kSlimeRimColor = Color(0xA6FFFFFF);
const kSlimeGlossColor = Color(0xF2FFFFFF);
const kSlimeGlossSmall = Color(0xA6FFFFFF);

/// The body is see-through. Below about 0.8 the legs behind it show through
/// and it stops reading as one creature.
const kSlimeBodyAlpha = 0.88;

/// A darker band just inside the outline: the long way through the jelly.
const kSlimeEdgeTint = Color(0x593E86B8);
const kSlimeEdgeWidth = 0.22;

/// Occlusion under the belly, where the light cannot reach.
const kSlimeCoreShadow = Color(0x33194E73);

/// Fraction of the body radius taken by the gloss highlight.
const kGlossRatio = 0.30;
const kGlossBlur = 9.0;
const kRimWidth = 5.0;

/// Brick, lit face through to the shaded underside.
const kBrickLightColor = Color(0xFFDC9075);
const kBrickMidColor = Color(0xFFC0604A);
const kBrickDeepColor = Color(0xFF8B3D2F);
const kMortarShadeColor = Color(0xFFC3B2A0);
const kWallGrimeColor = Color(0x162A1109);
const kWallBaseShadow = Color(0x592A1109);

/// The inside face of the hole. A wall has thickness, and you should be able
/// to see it in the opening.
const kHoleBevelColor = Color(0xFF6B2E22);
const kHoleBevelWidth = 9.0;

/// Per-brick colour jitter, so no two courses look stamped from one tile.
const kBrickJitter = 0.10;
const kBrickSpeckles = 3;

// ---------------------------------------------------------------------------
// The tap click
//
// Every control in the game makes it: the shape pad, the lane arrows, the
// pause button, and every slab on every menu. A press with no sound reads as a
// press that did not register, and a child's answer to that is to press again.
// ---------------------------------------------------------------------------

/// Well under the game's own sounds. This confirms a press; it is not an
/// event, and it must never talk over the chime for getting a wall right.
const kTapVolume = 0.35;

/// Presses closer together than this are one press to the ear, and every extra
/// click is a platform call for nothing.
const kTapMinGapMs = 45;

/// Players kept ready. A child drumming on the shape pad can have several
/// clicks overlapping, and building a player per press is what makes UI sound
/// stutter on a phone.
const kTapPoolMin = 2;
const kTapPoolMax = 4;

/// The sun, and the haze that sits on the horizon under it.
const kSunColor = Color(0x59FFF8DC);
const kSunCoreColor = Color(0x8CFFFDF0);
const kSunCentre = Offset(0.74, 0.17);
const kSunRadius = 132.0;
const kHazeColor = Color(0x4DEAF7FF);

/// Shafts of light leaning away from the sun. Barely there on purpose: they
/// should read as weather, not as a lens effect.
const kSunShafts = 4;
const kSunShaftColor = Color(0x12FFF6D8);
const kSunShaftLength = 620.0;
const kSunShaftWidth = 54.0;
const kSunShaftSpread = 0.22;
const kSunShaftBlur = 26.0;

// ---------------------------------------------------------------------------
// Weather
//
// Clouds live in their own band rather than in the sky image, because a cloud
// that never moves is a wallpaper pattern. They drift very slowly - they are
// the furthest thing in the scene, so they should barely shift.
// ---------------------------------------------------------------------------

const kCloudBandH = 290.0;
const kCloudBandY = 8.0;

/// Fraction of the world speed the cloud band drifts at.
const kCloudDriftFactor = 0.03;

const kCloudCount = 6;

/// Cumulus are wider than they are tall, and sit on a flat base.
const kCloudAspect = 0.52;
const kCloudMinW = 84.0;
const kCloudMaxW = 140.0;

/// Where in the band they sit, top to bottom. Kept in the upper part of it:
/// clouds that hang down onto the hills read as fog.
const kCloudHighest = 0.2;
const kCloudLowest = 0.46;

/// Puffs per cloud, and how far they may wander from the centre line.
const kCloudPuffs = 7;
const kCloudPuffSpread = 0.46;

/// Lit crown, shaded belly. A cloud with a single flat white is a sticker.
const kCloudLitColor = Color(0xFFFFFFFF);
const kCloudMidColor = Color(0xFFF0F7FD);
const kCloudShadeColor = Color(0xFFC9DCEB);
const kCloudBaseShadow = Color(0x33A9C6DC);

/// The high thin stuff, well above the cumulus.
const kCirrusCount = 6;
const kCirrusColor = Color(0x40FFFFFF);
const kCirrusW = 300.0;
const kCirrusH = 13.0;
const kCirrusBlur = 9.0;

/// Clouds are kept clear of the tile edges by this fraction of the width, so
/// two copies of the band can be laid end to end without cutting one in half.
const kCloudEdgeGuard = 0.16;
const kCloudSeed = 4;

/// How far down from the horizon the haze reaches.
const kHazeDepth = 70.0;

/// Grass, near the camera through to the horizon. Distance washes colour out;
/// keeping the far end flatter is what gives the ground depth.
///
/// Three stops, not two: real ground goes warm and yellow where the light hits
/// it flat in the middle distance, and only cools again close to the camera. A
/// straight ramp between two greens is the colour of a golf simulator.
const kGrassNearColor = Color(0xFF56A85E);
const kGrassMidColor = Color(0xFF7FBC65);
const kGrassFarColor = Color(0xFF9CCBA1);
const kGrassMidStop = 0.34;

/// Patches of longer and shorter grass, laid over the ramp. Low alpha, because
/// they are meant to be felt as texture rather than seen as shapes.
const kGrassPatchDeepColor = Color(0x5A2A6339);
const kGrassPatchLitColor = Color(0x5AC9E394);
const kVergeBladeColor = Color(0xFF3F8A4A);
const kVergeBladeLitColor = Color(0xFF7CB85C);

const kPathNearColor = Color(0xFFE7CE9F);
const kPathFarColor = Color(0xFFD8C4A2);

/// Tree and bush shading.
///
/// Foliage in sunlight goes yellow, foliage in its own shade goes blue. Using
/// a lighter and a darker version of one green instead is what makes painted
/// trees look like cut paper.
const kTreeLeafLightColor = Color(0xFF8CC162);
const kTreeLeafDeepColor = Color(0xFF23603C);
const kTrunkDarkColor = Color(0xFF5A3823);
const kBushLightColor = Color(0xFF77B45C);

// ---------------------------------------------------------------------------
// UI. Logical pixels, not world units: a landscape phone gives about
// 800 x 360 of those.
// ---------------------------------------------------------------------------

// In-game controls, in the same language as the menu: a cream face sitting on
// a darker lip, which sinks when pressed. Translucent rather than solid, so
// the path the runner is on is never fully hidden by its own buttons.

// Frosted glass: pale, translucent, with a bright edge. The world shows
// through, which keeps the bottom of the screen from turning into a solid bar
// of furniture, and the white glyph stays legible over anything.

const kPadFace = Color(0x8FE8F6FF);
const kPadFaceActive = Color(0xC7FFFFFF);
const kPadEdge = Color(0x99FFFFFF);
const kPadEdgeWidth = 2.5;
const kGameInk = Color(0xFF2B4A5C);

/// The worn shape is ringed in green and glows, the way the reference marks
/// its selection. Green means "this is the one you are" everywhere else too.
const kPadActiveRing = Color(0xFF56E08A);
const kPadActiveGlow = Color(0x8056E08A);
const kPadGlowBlur = 14.0;

/// A soft shadow, not the menu's hard lip.
///
/// The lip reads as thickness on a wide opaque slab. Shrunk onto a small round
/// control and made translucent, it renders as a second offset circle sitting
/// below the button - a smudge rather than a side. A blurred shadow lifts
/// these off the world without drawing a shape of its own.
const kPadShadow = Color(0x2E102A18);
const kPadShadowBlur = 12.0;
const kPadShadowDrop = 3.0;

/// How far a control shrinks while held, in place of sinking onto a lip.
const kPadPressScale = 0.93;

// The HUD has to read on grass, on sky and on brick. A backing card solves
// that but eats screen and hides the world; a heavy outline solves it for
// nothing, which is what game HUDs have always done.

const kHudInk = Color(0xFFFFFFFF);
const kHudOutline = Color(0xFF2B4A5C);
const kHudOutlineWidth = 6.0;

/// Hearts, pink rather than red: it sits better against the grass, and reads
/// as a game heart rather than as a warning.
const kHeartFill = Color(0xFFFF5E9C);

const kGameCard = Color(0xF0FFFDF5);
const kHudPillRadius = 24.0;
const kHudPillPadX = 14.0;
const kHudPillPadY = 5.0;

const kShapeButton = 92.0;
const kShapeButtonGap = 16.0;
const kMinTapTarget = 88.0;
const kShapeButtonRadius = 24.0;
const kShapeGlyphInset = 26.0;
const kActiveRingWidth = 4.0;
const kPadBottomInset = 14.0;

/// How much the active shape stands up over the other two.
const kActiveLift = 1.08;

const kHudPad = 18.0;
const kHeartSize = 26.0;
const kHeartGap = 4.0;
// The score used to be padded to five digits everywhere it appeared. It is
// shown plainly now: this game's scores live in the hundreds, and 00400 both
// promised a scale the game does not have and read as a smaller number than it
// was. Section 14 of the build document still says zero-padded; this overrides
// it deliberately.
const kScoreFontSize = 27.0;

/// Lane arrows, in the bottom corners.
///
/// Smaller than the shape buttons on purpose. Both matter, but the shape is
/// the thing being read off the wall, and a lane nudge can also be made with
/// a swipe anywhere on the screen. The tap target stays at the minimum even
/// though the face is smaller than it.
const kLaneArrow = 72.0;
const kLaneArrowIcon = 36.0;

/// How far controls stay clear of the top edge, where the system claims the
/// pull-down gesture even in immersive mode.
const kEdgeGestureInset = 26.0;

const kPauseButton = 54.0;
const kPauseIcon = 32.0;


/// Pause and game over: the title, and the score under it.
const kPanelTitleSize = 26.0;
const kPanelScoreSize = 24.0;

const kOverlayPad = 18.0;

const kUiScrim = Color(0x66000000);
const kUiInk = Color(0xFF2A3A44);
const kUiAccent = Color(0xFF3FBF6E);
const kUiHeart = Color(0xFFE8554E);

/// A spent life. Left on screen as an outline rather than removed, so a child
/// can always see how many they started with.
const kHeartSpent = Color(0x40E8554E);

/// Panels and buttons are lit like everything else: a brighter top edge, a
/// slightly deeper bottom, and a shadow underneath.
// ---------------------------------------------------------------------------
// Menu.
//
// Bright and chunky, played over the live world rather than on a background of
// its own: the game's sky and path keep drifting behind the cards, so the menu
// and the game are obviously the same place. Every button is a solid slab with
// a darker lip under it, which is the shape a small child reads as pressable.
// ---------------------------------------------------------------------------

const kMenuCard = Color(0xFFFFFDF5);
const kMenuCardEdge = Color(0xFFF2C14E);
const kMenuShadow = Color(0x38102A18);

// The menu's own scene: a storybook meadow, painted rather than played. Same
// palette as the game so the two are obviously one place, but nothing in it
// moves under its own steam and there is no runner in it.
// The sky. Four stops rather than three, and the top one is a proper blue
// instead of a pale one: a sky that starts washed out has nowhere left to go,
// which is why the old one read as a flat sheet of colour with a sun stuck on
// it. Deep overhead, bright in the middle, warm where it meets the ground.
const kMenuSkyTop = Color(0xFF3D7CD6);
const kMenuSkyMid = Color(0xFF5FC0EC);
const kMenuSkyLow = Color(0xFFAEE5F3);

/// The last band before the ground, warm rather than blue. This is the sun
/// reaching the horizon, and it is what makes the light in the picture come
/// from somewhere.
const kMenuSkyWarm = Color(0xFFFFE6C4);

/// Broad wedges of light thrown across the whole sky from the sun.
///
/// Faint enough to be atmosphere rather than decoration, but they are what
/// stops the sky being an empty gradient: they give it a direction, and they
/// reach into the corners the gradient leaves bare.
const kMenuBurstCount = 18;
const kMenuBurstColor = Color(0x1FFFFFFF);
const kMenuBurstTurn = 0.16;

/// A hot air balloon, drifting. The sky needs one thing in it with a size you
/// already know, because that is what gives everything behind it a distance.
///
/// One, not two. The second had nowhere to be: the right of the sky belongs to
/// the buttons, the middle belongs to the sun, and putting it in the middle
/// anyway parked it squarely over the sun's face.
const kMenuBalloons = <(double, double, double, int)>[
  (0.085, 0.38, 1.0, 0),
];
const kMenuBalloonH = 0.19;
const kMenuBalloonBob = 7.0;
const kMenuBalloonBasket = Color(0xFF9A6B3F);

const kMenuHillFar = Color(0xFF9AD7A6);
const kMenuHillMid = Color(0xFF6FC583);
const kMenuHillNear = Color(0xFF4FAE5B);
const kMenuHillRim = Color(0xFF8CD79C);
const kMenuSun = Color(0xFFFFE9A3);
const kMenuSunCore = Color(0xFFFFF6D8);
const kMenuSparkle = Color(0xB3FFFFFF);
const kMenuCloud = Color(0xF2FFFFFF);

/// Where the ground starts. Everything above it is sky and mountains,
/// everything below is meadow.
const kMenuHorizon = 0.60;

/// The mountain range behind the hills.
///
/// It is what turns a backdrop into a distance. Three green ridges stacked on
/// a blue wash gave the picture nothing beyond about a hundred metres, so the
/// menu had no distance for a path to run into.
/// Their feet are below the horizon and hidden by the meadow, so the height
/// here is the whole mountain and only the top of it is ever seen. Cut these
/// and the range turns into a row of bumps on the skyline.
///
/// Set out by hand rather than rolled: the fourth peak is the one behind the
/// sun, and a random height there would put a mountain in front of it. A range
/// is a composition, not a random walk - the tall ones belong left of centre,
/// where nothing else in the layout is competing.
const kMenuPeakHeights = <double>[0.20, 0.28, 0.31, 0.145, 0.26, 0.22, 0.175];
const kMenuPeakBase = 0.645;
const kMenuPeakSeed = 13;
const kMenuPeakColor = Color(0xFFA0B9E1);
const kMenuPeakShade = Color(0x333E5C8C);
const kMenuSnowColor = Color(0xFFF6FBFF);

/// A peak shorter than this keeps its head bare: snow on every one of them
/// reads as a pattern rather than as height.
const kMenuSnowFrom = 0.235;
const kMenuSnowDrop = 0.26;

/// The horizon, softened. Distance puts air between you and the ground, and
/// without it the meadow meets the sky along a drawn line.
const kMenuHazeDepth = 0.06;
const kMenuHazeAlpha = 0.85;

/// The two rolling rises between the horizon and the foreground.
const kMenuRidgeFarY = 0.665;
const kMenuRidgeMidY = 0.775;

/// The path, winding out of the distance to the runner's feet.
///
/// This is the road the game is actually run down. Having it start on the
/// menu, with the character standing on it, is what makes PLAY read as setting
/// off rather than as opening a screen.
const kMenuPathTopX = 0.40;
const kMenuPathTopHalf = 0.007;
const kMenuPathFootX = 0.30;

/// Half the road's width where it leaves the bottom of the frame. Modest: a
/// road wide enough to be generous in the middle distance swallows the entire
/// foreground by the time it reaches you.
const kMenuPathFootHalf = 0.115;

/// The castle, up on the far ridge.
///
/// Small, and off to the left where the range is tallest. At the head of the
/// road, which is where it wants to go, it sits directly behind the runner and
/// all that shows is a lilac slab either side of the character.
const kMenuCastleX = 0.235;
const kMenuCastleW = 0.055;
const kMenuCastleH = 0.10;
const kMenuCastleStone = Color(0xFFC9B4EA);
const kMenuCastleRoof = Color(0xFF9078CC);

/// Trees along the two ridges, as (across, which ridge, size). Kept off the
/// path and out of the middle, where the runner and the sun are.
const kMenuTrees = <(double, double, double)>[
  (0.03, kMenuRidgeFarY, 0.9),
  (0.09, kMenuRidgeFarY, 1.15),
  (0.15, kMenuRidgeFarY, 0.8),
  (0.55, kMenuRidgeFarY, 1.0),
  (0.63, kMenuRidgeFarY, 0.85),
  (0.72, kMenuRidgeFarY, 1.2),
  (0.86, kMenuRidgeFarY, 0.95),
  (0.94, kMenuRidgeFarY, 1.1),
  (0.02, kMenuRidgeMidY, 1.5),
  (0.66, kMenuRidgeMidY, 1.35),
  (0.79, kMenuRidgeMidY, 1.6),
  (0.97, kMenuRidgeMidY, 1.45),
];
const kMenuTreeH = 0.10;

/// Corners taken down a little, so the middle of the picture is the brightest
/// part of it and the cards read against a settled background instead of a
/// flat wash. Barely visible on its own, which is the point.
const kMenuVignette = Color(0x2E0B3247);
const kMenuVignetteStart = 0.52;

/// Flowers scattered over the meadow. Cheap, and they are the difference
/// between a green shape and somewhere things grow.
const kMenuFlowerCount = 54;
const kMenuFlowerSize = 2.4;
const kMenuFlowerSeed = 31;
const kMenuFlowerColors = <Color>[
  Color(0xCCFFFFFF),
  Color(0xB3FFE9A3),
  Color(0x99FFC7E0),
];

// The game's three shapes used to float loose in the sky here, and later in an
// arc over the runner's head. Both are gone. Wherever they were put they
// landed on something - half behind a cloud, half behind a level button, or
// stuck to a mountain peak directly above the character - and around the head
// they competed with the one part of the picture that has a face in it. The
// tagline carries the three shapes now, next to the sentence that explains
// them, which is the only place on this screen they have to earn.

/// One full drift of everything on the menu that moves.
const kMenuDriftSeconds = 7;

const kMenuSparkleCount = 16;

/// Where the sun sits, and how big it is.
///
/// Low, and off to the right of the name. It started up in the corner the
/// world is lit from, but that corner is where the title goes; every place it
/// was tried after that put it behind something - the cloud band, the tagline,
/// or its own mountains. Here it has open sky above it and a deliberately low
/// peak behind it.
const kMenuSunX = 0.52;
const kMenuSunY = 0.36;
const kMenuSunR = 0.085;

/// Cloud positions, set out by hand rather than spaced evenly: an even spread
/// put one squarely on the sun, and the sun is the thing the whole sky is lit
/// from. The gap in the middle is its.
const kMenuCloudXs = <double>[0.15, 0.30, 0.68, 0.87];
const kMenuCloudTop = 0.04;
const kMenuCloudBand = 0.13;

/// The level picker: three pills in a row, the chosen one filled green like
/// the PLAY slab so it reads as the thing that is switched on.
const kLevelTileH = 60.0;
const kLevelTileRadius = 13.0;
const kLevelTileDepth = 4.0;
const kLevelTileGap = 11.0;
const kLevelTileFontSize = 14.0;

/// Air between the level's name and its best, so the two read as two things
/// rather than one stacked label.
const kLevelBestGap = 5.0;
const kLevelTileFill = Color(0xFFF2F7F3);
const kLevelTileEdge = Color(0xFFDCE7E0);
const kLevelTileInk = Color(0xFF7B8A82);

/// Each level carries its own best under its name, so the three can be
/// compared at a glance. Smaller and dimmer than the name: it is what you have
/// done, not what you are choosing.
const kLevelBestFontSize = 11.0;
const kLevelBestInk = Color(0xFFA3B0A9);
const kLevelBestSelectedInk = Color(0xCCFFFFFF);

// ---------------------------------------------------------------------------
// App icon
//
// The home screen's sky and hills with the runner in front of them, drawn from
// the same palette and the same character code. All fractions of the icon box,
// so one set of numbers covers everything from a 48 pixel launcher tile to the
// 1024 store icon.
// ---------------------------------------------------------------------------

const kIconSunRadius = 0.072;
const kIconHillFarY = 0.70;
const kIconHillNearY = 0.82;

/// Where the runner's body centre sits. High enough that the feet land on the
/// near hill rather than below it.
const kIconRunnerY = 0.46;

/// Body width as a fraction of the icon.
///
/// On the composed icon it can be generous; the adaptive foreground has to
/// stay inside the launcher's safe circle, which is why that one is smaller.
const kIconRunnerWidth = 0.48;
const kIconRunnerWidthAdaptive = 0.44;

// Limbs, as multiples of the body radius. They start inside the body and are
// drawn behind it, so what shows is only the part past its edge - which is why
// the reach numbers are near 1 rather than 0.
const kIconLegLength = 0.62;
const kIconLegSpread = 0.34;
const kIconLegTop = 0.78;
const kIconArmLength = 0.56;
const kIconArmReach = 0.86;
const kIconArmDrop = 0.06;

// The face. Icon only.
//
// The runner has no face in the game, on purpose: you follow it up the path,
// so you are looking at its back. An icon is a portrait though - it is the
// thing that has to say "someone lives in here" from across a home screen -
// so this one turns round and looks at you.
//
// All fractions of the body radius. Kept low on the face and well clear of the
// gloss, which sits up and to the left where the light lands.
const kIconEyeX = 0.29;
const kIconEyeY = -0.02;
const kIconEyeR = 0.135;

/// Taller than wide, which reads as awake rather than surprised.
const kIconEyeSquash = 1.16;

/// A speck of white in each eye. Without it they are two holes.
const kIconCatchlight = 0.36;

const kIconSmileY = 0.3;
const kIconSmileW = 0.46;
const kIconSmileDrop = 0.17;
const kIconSmileStroke = 0.062;

/// Deep enough to hold against the pale gloss, blue enough to belong to the
/// jelly rather than being painted on it.
const kIconFaceInk = Color(0xFF1E4C6E);

/// The three shapes, drifting in the sky. The runner alone is a blue ball;
/// these are what say the game is about shapes. Kept few and small - an icon
/// has to survive being 48 pixels wide.
const kIconMoteCount = 3;
const kIconMoteSize = 0.062;
const kIconMoteOpacity = 0.88;
const kIconMoteRadius = 0.35;

/// Corner rounding of the legacy Android tile, as a fraction of its width.
/// iOS and adaptive Android mask their own, so they get none.
const kIconCorner = 0.22;

/// Android adaptive icons are 108dp with only the middle 72 guaranteed
/// visible: the launcher crops the rest to whatever shape it likes.
const kIconAdaptiveDp = 108.0;
const kMenuCloudCount = 4;

/// A setting is a row, not a line of text with a control stranded on the far
/// side of it: a tinted strip with its own icon, so a child can find the one
/// they want by its colour before they can read the label.
const kSettingRowFill = Color(0xFFF2F7F3);
const kSettingRowEdge = Color(0xFFDFE9E2);
const kSettingRowRadius = 15.0;
const kSettingRowPad = 9.0;
const kSettingBadge = 32.0;

/// The level bar. Thick, with a big thumb and coarse steps: precision is the
/// last thing a six year old's finger has.
const kLevelBarH = 10.0;
const kLevelThumb = 12.0;
const kLevelSteps = 5;

/// The same bar, squeezed for the pause panel: badge and slider on one line,
/// no label. A paused landscape phone has about 360 points of height, and a
/// panel a child has to scroll to reach KEEP GOING is a broken pause.
const kLevelBadgeCompact = 26.0;
const kLevelIconCompact = 17.0;
const kLevelRowCompactH = 30.0;

const kSwitchOffFill = Color(0xFFCBD6CF);
const kSwitchThumbColor = Color(0xFFFFFFFF);

const kMenuTagline = Color(0xFF6E7D75);
const kMenuStat = Color(0xFF46564E);
const kMenuButtonInk = Color(0xFFFFFFFF);

const kPlayFill = Color(0xFF41C275);
const kPlayEdge = Color(0xFF2C8B51);
const kHowToFill = Color(0xFF4A93E8);
const kHowToEdge = Color(0xFF3169AC);
const kSheetFill = Color(0xFFFFFFFF);
const kSheetEdge = Color(0xFFD9E2DC);

// ---------------------------------------------------------------------------
// The home screen's composition.
//
// Landscape is wide and short, so the menu is laid out across it rather than
// stacked down the middle: the name up in the top left, the runner standing on
// the hill below it, and everything you can press gathered in a column on the
// right where a thumb already is. A single centred column left two thirds of
// the screen as empty field and made the menu read as a form rather than a
// place.
// ---------------------------------------------------------------------------

/// Below either of these the screen cannot hold the spread layout and the menu
/// falls back to one centred, scrollable column.
const kMenuWideW = 620.0;
const kMenuWideH = 290.0;

/// How far the name and the runner are held off the left edge.
const kMenuBrandInset = 10.0;

/// The runner takes at most this much of the height, so a short landscape
/// phone shrinks it rather than pushing it off the bottom.
///
/// Generous on purpose. Small, it read as a sticker someone had left in the
/// corner; at this size it is the second thing on the screen after the name,
/// which is what it should be - it is the game.
const kMenuRunnerShare = 0.62;
const kMenuRunnerBox = 250.0;
const kMenuRunnerWidth = 0.46;

/// How far along the free half of the screen the runner stands, -1 at the left
/// edge and 1 at the right. Set so the feet land on the path rather than in the
/// grass beside it.
const kMenuRunnerAcross = -0.42;

/// Where the feet land: the crest of the near hill, so the runner is standing
/// on the scenery and not hovering over it.
const kMenuRunnerY = 0.42;
const kMenuRunnerBob = 5.0;
const kMenuRunnerSeconds = 3;

// ---------------------------------------------------------------------------
// The logo.
//
// The name used to sit in a cream card with a gold rim, which is the shape of
// a heading on a form. A game's name is a logo, and what makes it read as one
// is weight: a dark outline and a shadow under it, so the letters sit on the
// sky rather than float in front of it. Then it needs no box at all.
// ---------------------------------------------------------------------------

const kLogoSize = 46.0;
const kLogoSizeNarrow = 33.0;
const kLogoSpacing = 0.5;

/// Outline and shadow, both as fractions of the font size so the logo is the
/// same drawing at either size.
const kLogoOutline = Color(0xFF1E4C6E);
const kLogoOutlineWidth = 0.115;
const kLogoShadow = Color(0x59123246);
const kLogoShadowDrop = 0.085;
const kLogoShadowBlur = 0.06;

/// Letters ride a shallow wave and lean alternately, so the name bounces along
/// the way the runner does. Small numbers: past about a tenth of the font size
/// it stops reading as bounce and starts reading as broken kerning.
const kLogoBounce = 0.09;
const kLogoWaveStep = 1.05;
const kLogoTilt = 0.04;

/// The tagline sits on a translucent lozenge. Plain text over sky is legible
/// until a cloud drifts under it.
const kTaglinePill = Color(0xD9FFFFFF);
const kTaglinePillRadius = 18.0;
const kTaglinePadX = 13.0;
const kTaglinePadY = 7.0;
const kTaglineGlyph = 11.0;
const kTaglineGlyphGap = 4.0;

/// A slab's face is lit from the top, like everything else in the game: the
/// fill is the bottom of the gradient and this much white is mixed in at the
/// top. Enough to look moulded, not enough to look faded.
const kSlabSheen = 0.18;

/// One colour per letter of the title. Cycled, so a longer name still works.
const kTitleLetterColors = <Color>[
  Color(0xFFF2724B),
  Color(0xFFEE5D8A),
  Color(0xFFC158D6),
  Color(0xFF5B8DEF),
  Color(0xFF2FB8BE),
  Color(0xFF41C275),
  Color(0xFFF0A93B),
];

const kMenuColumnW = 330.0;
const kMenuButtonH = 50.0;
const kMenuCardRadius = 22.0;
const kMenuButtonRadius = 25.0;

/// The lip under a slab, and how far it sinks when pressed.
const kChunkyDepth = 6.0;

const kMenuButtonFontSize = 17.0;
const kMenuButtonSpacing = 1.6;
const kMenuButtonGap = 10.0;
const kMenuIconSize = 20.0;

const kMenuTaglineSize = 13.0;
const kMenuStatSize = 12.5;

