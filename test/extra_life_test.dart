import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/components/wall.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';

// The rewarded second chance.
//
// The ad itself cannot be tested here - there is no SDK in a test - but every
// rule around it can be, and those are the parts that quietly go wrong: a
// revive that restarts the score, one that drops the runner straight back onto
// the wall that killed them, or one that can be taken twice.

const _frame = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  /// The wall about to arrive, or null if the road is clear.
  Wall? nextWall(ShapeShifterGame game) {
    Wall? nearest;
    for (final wall in game.walls) {
      if (wall.resolved) continue;
      if (nearest == null || wall.z < nearest.z) nearest = wall;
    }
    return nearest;
  }

  /// Plays properly - matching every shape and stepping onto every track -
  /// until there is a score on the board worth coming back for.
  void playWell(ShapeShifterGame game, {required int untilScore}) {
    for (var i = 0; i < 60000 && game.score.value < untilScore; i++) {
      final wall = nextWall(game);
      if (wall != null) {
        game
          ..morph(wall.shape)
          ..moveToLane(wall.lane);
      }
      game.update(_frame);
    }
  }

  /// Then stops playing, and loses every life.
  void playUntilOut(ShapeShifterGame game) {
    for (var i = 0; i < 60000 && game.state != GameState.gameOver; i++) {
      // Never morph and never change track: sooner or later a wall does not
      // match and every life goes the same way.
      game.update(_frame);
    }
  }

  /// A finished run with something on the board.
  Future<ShapeShifterGame> spentRun({Level level = Level.medium}) async {
    final game = await boot();
    game
      ..chooseLevel(level)
      ..startRun();
    playWell(game, untilScore: kScorePerWall * 3);
    playUntilOut(game);
    return game;
  }

  group('extra life', () {
    test('is on offer once the last life is gone', () async {
      final game = await spentRun();
      expect(game.state, GameState.gameOver);
      expect(game.canOfferExtraLife, isTrue);
    });

    test('is not on offer mid-run', () async {
      final game = await boot();
      game.startRun();
      expect(game.canOfferExtraLife, isFalse);
    });

    test('carries on the run rather than restarting it', () async {
      final game = await spentRun();
      final scored = game.score.value;
      final collected = game.coins.value;
      expect(scored, greaterThan(0), reason: 'needs a score worth saving');

      game.reviveWithExtraLife();

      expect(game.state, GameState.running);
      expect(game.lives.value, 1);
      // The whole point. A revive that zeroed these would be PLAY AGAIN with
      // an advert in front of it, and nobody would watch one for that.
      expect(game.score.value, scored);
      expect(game.coins.value, collected);
    });

    test('clears the road so the life is not spent on arrival', () async {
      final game = await spentRun();
      game.reviveWithExtraLife();

      // Nothing close enough to hit before the player can react.
      for (final wall in game.walls) {
        expect(wall.z, greaterThan(kReviveClearZ));
      }
      // And the runner is blinking while they get their bearings.
      expect(game.player.isInvulnerable, isTrue);
    });

    test('gives a breather before the next wall arrives', () async {
      final game = await spentRun();
      game.reviveWithExtraLife();

      // Far less than the breather: nothing may have reached the runner yet.
      for (var i = 0; i < (kReviveBreather * 0.5 * 60).round(); i++) {
        game.update(_frame);
      }
      expect(game.state, GameState.running);
      expect(game.lives.value, 1);
    });

    test('is only good for one go per run', () async {
      final game = await spentRun();
      game.reviveWithExtraLife();
      expect(game.canOfferExtraLife, isFalse);

      for (var i = 0; i < 60000 && game.state != GameState.gameOver; i++) {
        game.update(_frame);
      }
      expect(game.state, GameState.gameOver);
      // Out for good this time. Otherwise a player with patience for adverts
      // never has to stop and the score stops meaning anything.
      expect(game.canOfferExtraLife, isFalse);
    });

    test('a fresh run gets its own second chance back', () async {
      final game = await spentRun();
      game.reviveWithExtraLife();
      game.startRun();

      for (var i = 0; i < 60000 && game.state != GameState.gameOver; i++) {
        game.update(_frame);
      }
      expect(game.canOfferExtraLife, isTrue);
    });

    test('does nothing at all if the run is still going', () async {
      final game = await boot();
      game.startRun();
      final lives = game.lives.value;

      game.reviveWithExtraLife();

      expect(game.lives.value, lives, reason: 'must not top up a live run');
    });
  });
}
