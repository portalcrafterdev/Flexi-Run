import 'constants.dart';

/// How hard the game is set to play.
///
/// The speed is the same on all three. What changes is how close together the
/// walls arrive, how much else there is to think about, and how much room
/// there is to get it wrong - so a child who has learned the timing on one
/// level does not have to learn it again to move up.
///
/// [medium] is the game exactly as it was tuned before levels existed, and is
/// where a new player starts.
enum Level {
  easy(
    label: 'Easy',
    gapStart: kEasyGapStart,
    gapMin: kEasyGapMin,
    rampScore: kEasyRampScore,
    lives: kEasyLives,
    shieldEvery: kEasyShieldEvery,
    forgiveSeconds: kEasyForgiveSeconds,
    // The one difference that is not a number.
    centreLaneOnly: true,
  ),
  medium(
    label: 'Medium',
    gapStart: kMediumGapStart,
    gapMin: kMediumGapMin,
    rampScore: kMediumRampScore,
    lives: kMediumLives,
    shieldEvery: kMediumShieldEvery,
    forgiveSeconds: kMediumForgiveSeconds,
  ),
  hard(
    label: 'Hard',
    gapStart: kHardGapStart,
    gapMin: kHardGapMin,
    rampScore: kHardRampScore,
    lives: kHardLives,
    shieldEvery: kHardShieldEvery,
    forgiveSeconds: kHardForgiveSeconds,
  );

  const Level({
    required this.label,
    required this.gapStart,
    required this.gapMin,
    required this.rampScore,
    required this.lives,
    required this.shieldEvery,
    required this.forgiveSeconds,
    this.centreLaneOnly = false,
  });

  /// What the menu calls it.
  final String label;

  /// Seconds between walls at score zero, and the floor it tightens to.
  final double gapStart;
  final double gapMin;

  /// Score at which the gap reaches its floor and the game stops getting
  /// harder. Past it the run is a stamina test at a fixed pace.
  final double rampScore;

  final int lives;

  /// Clean passes per free shield.
  final int shieldEvery;

  /// How long a mismatched wall holds its verdict open. Small hands are late,
  /// and the smaller the hands the longer this wants to be.
  final double forgiveSeconds;

  /// Whether every wall opens on the middle track, leaving only the shape to
  /// solve. True on [easy] alone.
  final bool centreLaneOnly;

  /// How fast the gap closes per point of score. Derived, so the start, the
  /// floor and the ramp length can never drift apart.
  double get gapDecay => (gapStart - gapMin) / rampScore;
}

/// Where a player who has never chosen starts.
const kStartLevel = Level.medium;
