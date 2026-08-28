// The score leaderboards, one per level.
//
// One board per level rather than one overall, because the levels are not
// comparable: Easy gives more than twice the thinking time for the same ten
// points a wall, so a single board would be topped entirely by Easy runs and
// would tell nobody anything. Prefs keeps the best score the same way and for
// the same reason.

import 'level.dart';

/// A leaderboard, with the identifier each store knows it by.
///
/// All three exist in Play Console. A board added later starts with an empty
/// id, and [Board.isReady] keeps it out of everything until it is filled in -
/// the alternative being a submission to '' on every run, which fails quietly
/// and looks exactly like the feature being broken.
enum Board {
  easy(Level.easy, 'CgkIlIeMzOsGEAIQGQ', 'easy_best_score'),
  medium(Level.medium, 'CgkIlIeMzOsGEAIQGg', 'medium_best_score'),
  hard(Level.hard, 'CgkIlIeMzOsGEAIQGw', 'hard_best_score');

  const Board(this.level, this.androidId, this.iosId);

  final Level level;
  final String androidId;

  /// Ours to choose, and to enter in App Store Connect exactly as written -
  /// Game Center has no export to copy back from.
  final String iosId;

  /// Whether this board has been created yet, on either store.
  ///
  /// Keyed off the Play id for both platforms on purpose. The Game Center ids
  /// are ours and are written here before the boards exist, so they cannot
  /// signal anything; the Play id only appears once the board is really there.
  /// The two stores are set up together, so one switch is enough - and the
  /// failure it avoids is submitting to a board that does not exist on every
  /// single run.
  bool get isReady => androidId.isNotEmpty;

  /// The board for [level], or null while that one has no id yet.
  static Board? forLevel(Level level) {
    for (final board in values) {
      if (board.level == level) return board.isReady ? board : null;
    }
    return null;
  }
}
