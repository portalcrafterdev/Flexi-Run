import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/awards.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/shape_kind.dart';

// What a run is worth. The rule is pure arithmetic over RunStats, which is the
// whole reason it can be tested at all - neither store is reachable from here.

RunStats stats({
  int score = 0,
  Level level = Level.medium,
  int bestStreak = 0,
  int bestCleanWalls = 0,
  int shieldsEarned = 0,
  Set<ShapeKind>? shapesUsed,
}) => RunStats(
  score: score,
  level: level,
  bestStreak: bestStreak,
  bestCleanWalls: bestCleanWalls,
  shieldsEarned: shieldsEarned,
  shapesUsed: shapesUsed ?? <ShapeKind>{},
);

void main() {
  group('awardsFor', () {
    test('finishing anything at all earns First Run', () {
      expect(awardsFor(stats()), contains(Award.firstRun));
    });

    test('a nothing run earns only First Run', () {
      expect(awardsFor(stats()), <Award>{Award.firstRun});
    });

    test('the score ladder unlocks in order and keeps the ones below', () {
      expect(awardsFor(stats(score: kAwardScoreOne - 1)), <Award>{
        Award.firstRun,
      });
      expect(
        awardsFor(stats(score: kAwardScoreOne)),
        containsAll(<Award>[Award.downThePath]),
      );
      expect(
        awardsFor(stats(score: kAwardScoreFour)),
        containsAll(<Award>[
          Award.downThePath,
          Award.pastTheTrees,
          Award.overTheHills,
          Award.theLongRun,
        ]),
      );
    });

    test('Shape Shifter needs every shape, not a count of three', () {
      // Deliberately built off the enum rather than a literal 3, so adding the
      // triangle in v2 tightens this instead of silently passing.
      final all = ShapeKind.values.toSet();
      expect(awardsFor(stats(shapesUsed: all)), contains(Award.shapeShifter));

      final allButOne = all.toSet()..remove(ShapeKind.values.last);
      expect(
        awardsFor(stats(shapesUsed: allButOne)),
        isNot(contains(Award.shapeShifter)),
      );
    });

    test('the single run badges each need their own threshold', () {
      expect(
        awardsFor(stats(bestStreak: kAwardStreak)),
        contains(Award.tenInARow),
      );
      expect(
        awardsFor(stats(bestStreak: kAwardStreak - 1)),
        isNot(contains(Award.tenInARow)),
      );

      expect(
        awardsFor(stats(bestCleanWalls: kAwardCleanWalls)),
        contains(Award.notAScratch),
      );
      expect(
        awardsFor(stats(bestCleanWalls: kAwardCleanWalls - 1)),
        isNot(contains(Award.notAScratch)),
      );

      expect(
        awardsFor(stats(shieldsEarned: kAwardShields)),
        contains(Award.shieldStack),
      );
      expect(
        awardsFor(stats(shieldsEarned: kAwardShields - 1)),
        isNot(contains(Award.shieldStack)),
      );
    });

    group('the level badges say which level and mean it', () {
      test('Medium earns Stepping Up and nothing of Hard', () {
        final won = awardsFor(
          stats(score: kAwardLevelScore, level: Level.medium),
        );
        expect(won, contains(Award.steppingUp));
        expect(won, isNot(contains(Award.topOfTheHill)));
      });

      test('Hard earns Top of the Hill and not Medium', () {
        // The console text is published and has to stay true: "Score 100 on
        // Medium" is not something a Hard run did.
        final won = awardsFor(stats(score: kAwardLevelScore, level: Level.hard));
        expect(won, contains(Award.topOfTheHill));
        expect(won, isNot(contains(Award.steppingUp)));
      });

      test('Easy earns neither, however high the score', () {
        final won = awardsFor(stats(score: kAwardScoreFour, level: Level.easy));
        expect(won, isNot(contains(Award.steppingUp)));
        expect(won, isNot(contains(Award.topOfTheHill)));
      });
    });

    test('Coin Hunter is never earned by a run', () {
      // It is a lifetime total pushed as absolute progress. A Play incremental
      // achievement accumulates permanently, so counting it per run would keep
      // adding a finished run's coins every time that run was reported.
      final everything = stats(
        score: kAwardScoreFour,
        level: Level.hard,
        bestStreak: kAwardStreak,
        bestCleanWalls: kAwardCleanWalls,
        shieldsEarned: kAwardShields,
        shapesUsed: ShapeKind.values.toSet(),
      );
      expect(awardsFor(everything), isNot(contains(Award.coinHunter)));
    });

    test('a perfect run earns every other badge', () {
      final everything = stats(
        score: kAwardScoreFour,
        level: Level.hard,
        bestStreak: kAwardStreak,
        bestCleanWalls: kAwardCleanWalls,
        shieldsEarned: kAwardShields,
        shapesUsed: ShapeKind.values.toSet(),
      );
      final won = awardsFor(everything);
      // Every award except Coin Hunter and Medium's own badge.
      expect(won, hasLength(Award.values.length - 2));
    });

    test('is pure: the same run twice gives the same answer', () {
      final run = stats(score: kAwardScoreTwo, bestStreak: kAwardStreak);
      expect(awardsFor(run), awardsFor(run));
    });
  });

  group('identifiers', () {
    test('every award has both a Play and a Game Center id', () {
      for (final award in Award.values) {
        expect(award.androidId, isNotEmpty, reason: '${award.name} android');
        expect(award.iosId, isNotEmpty, reason: '${award.name} ios');
      }
    });

    test('the Play ids match the console export', () {
      // games-ids.xml is what Play Console handed back. The ids in Dart are a
      // hand copy of it, and the two drifting apart would unlock nothing at
      // all while looking perfectly fine in a diff.
      final xml = File(
        'android/app/src/main/res/values/games-ids.xml',
      ).readAsStringSync();

      String? exported(String name) => RegExp(
        '<string name="achievement_$name"[^>]*>([^<]+)</string>',
      ).firstMatch(xml)?.group(1);

      for (final award in Award.values) {
        // first_run in the resource file, firstRun in Dart, one name in the
        // CSV - the iOS id is already the snake case form, so it is the join.
        expect(
          exported(award.iosId),
          award.androidId,
          reason: '${award.name} does not match games-ids.xml',
        );
      }
    });

    test('the CSV lists exactly the awards the game knows about', () {
      final rows = File('tool/play_games/AchievementsMetadata.csv')
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      expect(rows, hasLength(Award.values.length));

      // Matched through the icon mappings rather than by rebuilding the
      // display name from the id: the names are title case with small words
      // left alone ("Down the Path"), and encoding that rule here would only
      // be a second place for it to be wrong.
      final mappings = File('tool/play_games/AchievementsIconsMappings.csv')
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty);

      final iconFor = <String, String>{
        for (final line in mappings)
          line.split(',').first: line.split(',').last.replaceAll('.png', ''),
      };

      // Every metadata row has an icon, and every icon belongs to an award.
      final named = rows.map((r) => r.split(',').first).toSet();
      expect(named, iconFor.keys.toSet(), reason: 'metadata vs icon mappings');
      expect(
        named.map((n) => iconFor[n]).toSet(),
        Award.values.map((a) => a.iosId).toSet(),
        reason: 'icon files vs award ids',
      );
    });

    test('no id is shared between two awards', () {
      // A copy-paste slip here would silently unlock the wrong badge, and the
      // ids are opaque enough that nobody would spot it by eye.
      final android = Award.values.map((a) => a.androidId).toSet();
      final ios = Award.values.map((a) => a.iosId).toSet();
      expect(android, hasLength(Award.values.length));
      expect(ios, hasLength(Award.values.length));
    });
  });
}
