// The twelve achievements, and the pure rule for what a finished run earned.
//
// Nothing in here touches a platform. Deciding what was won is arithmetic over
// RunStats and is unit tested as such; sending it anywhere is Games's problem.
// That split is the reason this can be tested at all - Play Games and Game
// Center are both unreachable from a test host.

import 'level.dart';
import 'shape_kind.dart';

/// Score milestones, in the order a player meets them.
const kAwardScoreOne = 50;
const kAwardScoreTwo = 100;
const kAwardScoreThree = 200;
const kAwardScoreFour = 500;

/// Clean passes in a row for "Ten in a Row".
const kAwardStreak = 10;

/// Walls cleared between one lost life and the next for "Not a Scratch".
const kAwardCleanWalls = 25;

/// Shields earned inside one run for "Shield Stack".
const kAwardShields = 5;

/// What a run has to reach on Medium or Hard to count for that level's badge.
const kAwardLevelScore = 100;

/// Coins collected across every run for "Coin Hunter", the one incremental
/// achievement. Must match Steps Needed in AchievementsMetadata.csv.
const kAwardCoinTarget = 500;

/// An achievement, with the identifier each store knows it by.
///
/// The Android IDs come from Play Console via games-ids.xml. The iOS IDs are
/// ours to choose and must be entered in App Store Connect exactly as written
/// here - Game Center has no equivalent export to copy back from.
enum Award {
  firstRun('CgkIlIeMzOsGEAIQGA', 'first_run'),
  shapeShifter('CgkIlIeMzOsGEAIQFQ', 'shape_shifter'),
  downThePath('CgkIlIeMzOsGEAIQDQ', 'down_the_path'),
  pastTheTrees('CgkIlIeMzOsGEAIQFw', 'past_the_trees'),
  overTheHills('CgkIlIeMzOsGEAIQDg', 'over_the_hills'),
  theLongRun('CgkIlIeMzOsGEAIQEQ', 'the_long_run'),
  tenInARow('CgkIlIeMzOsGEAIQFA', 'ten_in_a_row'),
  notAScratch('CgkIlIeMzOsGEAIQDw', 'not_a_scratch'),
  shieldStack('CgkIlIeMzOsGEAIQEA', 'shield_stack'),
  steppingUp('CgkIlIeMzOsGEAIQFg', 'stepping_up'),
  topOfTheHill('CgkIlIeMzOsGEAIQEw', 'top_of_the_hill'),

  /// The only incremental one. Never returned by [awardsFor]: its progress is
  /// pushed as a running total instead, because a Play incremental achievement
  /// accumulates permanently and cannot be reset or counted per run.
  coinHunter('CgkIlIeMzOsGEAIQEg', 'coin_hunter');

  const Award(this.androidId, this.iosId);

  final String androidId;
  final String iosId;
}

/// What one finished run did, in the terms the achievements are written in.
class RunStats {
  const RunStats({
    required this.score,
    required this.level,
    required this.bestStreak,
    required this.bestCleanWalls,
    required this.shieldsEarned,
    required this.shapesUsed,
  });

  final int score;
  final Level level;

  /// Longest run of clean passes, not the streak left standing at the end -
  /// which is always zero, because a run ends by hitting something.
  final int bestStreak;

  /// Most walls cleared between two lost lives. Shield smashes count: the
  /// badge is "without losing a life", and spending a shield is not that.
  final int bestCleanWalls;

  final int shieldsEarned;

  /// Which shapes were worn through a wall. Morphing on the spot does not
  /// count - the badge is for using them, not for pressing the buttons.
  final Set<ShapeKind> shapesUsed;
}

/// Every achievement [stats] earned. Pure, total, and safe to call twice.
Set<Award> awardsFor(RunStats stats) {
  final won = <Award>{
    // Finishing at all. There is no way to reach here without having run.
    Award.firstRun,
  };

  if (stats.shapesUsed.length == ShapeKind.values.length) {
    won.add(Award.shapeShifter);
  }
  if (stats.score >= kAwardScoreOne) won.add(Award.downThePath);
  if (stats.score >= kAwardScoreTwo) won.add(Award.pastTheTrees);
  if (stats.score >= kAwardScoreThree) won.add(Award.overTheHills);
  if (stats.score >= kAwardScoreFour) won.add(Award.theLongRun);

  if (stats.bestStreak >= kAwardStreak) won.add(Award.tenInARow);
  if (stats.bestCleanWalls >= kAwardCleanWalls) won.add(Award.notAScratch);
  if (stats.shieldsEarned >= kAwardShields) won.add(Award.shieldStack);

  // Read literally, because the console text says "on Medium" and "on Hard"
  // and a badge must not claim something the player did not do. A player who
  // only ever touches Hard does not collect Medium's, which is the honest
  // reading of what is written on it.
  if (stats.score >= kAwardLevelScore) {
    switch (stats.level) {
      case Level.medium:
        won.add(Award.steppingUp);
      case Level.hard:
        won.add(Award.topOfTheHill);
      case Level.easy:
        break;
    }
  }

  return won;
}
