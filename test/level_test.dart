import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/lane.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';
import 'package:flexirun/ui/level_picker.dart';

// What each level actually does, checked by playing it rather than by reading
// the numbers back off the enum - difficulty_test.dart already does that.

const _frame = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  /// Every track a wall opened on over a long stretch of play. Sampled every
  /// frame, so walls that come and go between checks are still counted.
  Set<Lane> lanesUsed(ShapeShifterGame game, {int frames = 6000}) {
    final lanes = <Lane>{};
    for (var i = 0; i < frames; i++) {
      game.update(_frame);
      lanes.addAll(game.walls.map((wall) => wall.lane));
    }
    return lanes;
  }

  group('easy', () {
    test('opens every wall on the middle track', () async {
      final game = await boot();
      game.chooseLevel(Level.easy);
      game.startRun();

      expect(
        lanesUsed(game),
        <Lane>{Lane.centre},
        reason: 'easy drops the lane mechanic, so only the shape is left',
      );
    });

    test('starts with more lives than medium', () async {
      final game = await boot();
      game.chooseLevel(Level.easy);
      game.startRun();

      expect(game.lives.value, Level.easy.lives);
      expect(game.lives.value, greaterThan(Level.medium.lives));
    });
  });

  test('medium still uses all three tracks', () async {
    final game = await boot();
    game.startRun();

    expect(
      lanesUsed(game).length,
      greaterThan(1),
      reason: 'the lane mechanic is what easy removes and medium keeps',
    );
  });

  group('choosing a level', () {
    test('is remembered between sessions', () async {
      final game = await boot();
      game.chooseLevel(Level.hard);

      expect(Prefs.level, Level.hard);
      expect((await boot()).level.value, Level.hard);
    });

    test('is refused mid-run, so a score cannot change its own rules', () async {
      final game = await boot();
      game.startRun();
      game.chooseLevel(Level.easy);

      expect(game.level.value, Level.medium);
    });

    test('is allowed again once the run is over', () async {
      final game = await boot();
      game.startRun();
      game.goToMenu();
      game.chooseLevel(Level.easy);

      expect(game.level.value, Level.easy);
    });
  });

  group('high score', () {
    test('is kept per level, so easy cannot beat hard', () async {
      await Prefs.setHighScore(Level.easy, 900);

      expect(Prefs.highScore(Level.easy), 900);
      expect(Prefs.highScore(Level.hard), 0);
    });

    test('follows the level the menu is showing', () async {
      await Prefs.setHighScore(Level.medium, 540);
      await Prefs.setHighScore(Level.hard, 120);

      final game = await boot();
      expect(game.highScore.value, 540);

      game.chooseLevel(Level.hard);
      expect(game.highScore.value, 120);
    });

    testWidgets('is shown on each level button, its own and no other', (
      tester,
    ) async {
      await Prefs.setHighScore(Level.easy, 540);
      await Prefs.setHighScore(Level.hard, 120);
      final game = await boot();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LevelPicker(game: game))),
      );

      // Named, so the number cannot be mistaken for something else, and not
      // padded out to five digits it will never reach.
      expect(find.text('Best 540'), findsOneWidget);
      expect(find.text('Best 120'), findsOneWidget);
      // Medium has never been played, and says so rather than borrowing one.
      expect(find.text('Best 0'), findsOneWidget);
    });

    test('a best from before there were levels lands on medium', () async {
      // Medium is the tuning that score was set on, and a player who has been
      // at this for weeks should not open the update to find it gone.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'high_score': 540,
      });
      await Prefs.init();

      expect(Prefs.highScore(Level.medium), 540);
      expect(Prefs.highScore(Level.easy), 0);
      expect(Prefs.highScore(Level.hard), 0);
    });
  });
}
