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
const kMinWallSeparationZ = 300.0;

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
const kPrioHills = 1;
const kPrioRoad = 2;

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
// Roadside scenery
// ---------------------------------------------------------------------------

const kSceneryCount = 14;
const kScenerySpawnZ = 2400.0;
const kSceneryLateral = 520.0;
const kSceneryLateralJitter = 240.0;
const kSceneryBaseSize = 300.0;

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
const kBackTuftRatio = 0.3;

const kShieldRingWidth = 11.0;
const kShardRadius = 8.0;

const kSkyTop = Color(0xFF8FD8F5);
const kSkyBottom = Color(0xFFDFF3FF);
const kCloudColor = Color(0xFFFFFFFF);
const kHillsFarColor = Color(0xFFA8D8B0);
const kHillsMidColor = Color(0xFF74C084);
const kCastleColor = Color(0xFFCBB8E8);
const kCastleRoofColor = Color(0xFF8A6FC4);
const kTreeTrunkColor = Color(0xFF8A5A3B);
const kTreeLeafColor = Color(0xFF43A05A);
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

/// The sun, and the haze that sits on the horizon under it.
const kSunColor = Color(0x59FFF8DC);
const kSunCoreColor = Color(0x8CFFFDF0);
const kSunCentre = Offset(0.74, 0.17);
const kSunRadius = 132.0;
const kHazeColor = Color(0x4DEAF7FF);

/// How far down from the horizon the haze reaches.
const kHazeDepth = 70.0;

/// Grass, near the camera through to the horizon. Distance washes colour out;
/// keeping the far end flatter is what gives the ground depth.
const kGrassNearColor = Color(0xFF4FB65F);
const kGrassFarColor = Color(0xFF8FD49A);
const kPathNearColor = Color(0xFFE7CE9F);
const kPathFarColor = Color(0xFFD8C4A2);

/// Tree and bush shading.
const kTreeLeafLightColor = Color(0xFF6FC47F);
const kTreeLeafDeepColor = Color(0xFF2E7A44);
const kTrunkDarkColor = Color(0xFF6B4229);
const kBushLightColor = Color(0xFF56A96B);

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
const kScoreDigits = 5;
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
const kMenuSkyTop = Color(0xFF5FC3EE);
const kMenuSkyMid = Color(0xFF9FDDF6);
const kMenuSkyLow = Color(0xFFE3F5FD);
const kMenuHillFar = Color(0xFF8ED09A);
const kMenuHillMid = Color(0xFF5FBE72);
const kMenuHillNear = Color(0xFF3FA557);
const kMenuHillRim = Color(0xFF7ACB8C);
const kMenuSun = Color(0xFFFFE9A3);
const kMenuSunCore = Color(0xFFFFF6D8);
const kMenuSparkle = Color(0xB3FFFFFF);
const kMenuCloud = Color(0xF2FFFFFF);

/// The drifting shape motifs, in place of the coins a collecting game would
/// float here. Slow enough to be scenery, not decoration that demands the eye.
const kMenuMoteCount = 7;
const kMenuMoteSize = 26.0;
const kMenuMoteBob = 9.0;
const kMenuMoteSeconds = 7;
const kMenuMoteOpacity = 0.55;

const kMenuSparkleCount = 16;
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

const kMenuTitleSize = 32.0;
const kMenuTitleSpacing = 1.5;

/// The three shapes, small, beside the tagline.
const kMenuRuleGlyph = 12.0;
const kMenuRuleGap = 5.0;

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

