import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/components/wall.dart';
import 'package:flexirun/core/awards.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';

// What a real run hands the achievements layer.
//
// The store calls cannot be tested here - there is no SDK on a test host - but
// everything before them can, and that is where the quiet mistakes live: coins
// banked twice because a run ended twice, or a badge credited to a run that
// did not earn it.

const _frame = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  Wall? nextWall(ShapeShifterGame game) {
    Wall? nearest;
    for (final wall in game.walls) {
      if (wall.resolved) continue;
      if (nearest == null || wall.z < nearest.z) nearest = wall;
    }
    return nearest;
  }

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

  void playUntilOut(ShapeShifterGame game) {
    for (var i = 0; i < 60000 && game.state != GameState.gameOver; i++) {
      game.update(_frame);
    }
  }

  group('a finished run', () {
    test('banks its coins into the lifetime total', () async {
      final game = await boot();
      expect(Prefs.lifetimeCoins, 0);

      game.startRun();
      playWell(game, untilScore: 120);
      playUntilOut(game);
      // Read after the run ends: playing on to lose the last life picks up
      // more coins, and it is the final count that gets banked.
      final taken = game.coins.value;
      await Future<void>.delayed(Duration.zero);

      expect(taken, greaterThan(0), reason: 'the run collected nothing');
      expect(Prefs.lifetimeCoins, taken);
    });

    test('does not bank the same coins twice when revived', () async {
      final game = await boot();
      // The bug this pins: a run ends, an advert buys a second chance, and the
      // run ends again. Both endings report, and without the banked count the
      // coins from the first half are added to the lifetime total a second
      // time - so a child who watches adverts earns Coin Hunter twice as fast.
      game.startRun();
      playWell(game, untilScore: 120);
      playUntilOut(game);
      await Future<void>.delayed(Duration.zero);

      final afterFirstEnding = Prefs.lifetimeCoins;
      expect(afterFirstEnding, greaterThan(0));

      game.reviveWithExtraLife();
      expect(game.state, GameState.running);
      playWell(game, untilScore: game.score.value + 60);
      playUntilOut(game);
      final total = game.coins.value;
      await Future<void>.delayed(Duration.zero);

      // Every coin once: the run's own count, not the sum of two reports.
      expect(Prefs.lifetimeCoins, total);
      expect(Prefs.lifetimeCoins, greaterThan(afterFirstEnding));
    });

    test('records what it actually earned', () async {
      final game = await boot();
      game.startRun();
      playWell(game, untilScore: kAwardScoreTwo);
      playUntilOut(game);
      await Future<void>.delayed(Duration.zero);

      final won = Prefs.awardsWon;
      // Played well past 100 on the default level, so the ladder up to that
      // point and Medium's own badge are all genuinely earned.
      expect(won, contains(Award.firstRun.name));
      expect(won, contains(Award.downThePath.name));
      expect(won, contains(Award.pastTheTrees.name));
      expect(won, contains(Award.steppingUp.name));

      // And nothing above what the run reached.
      expect(won, isNot(contains(Award.theLongRun.name)));
      expect(won, isNot(contains(Award.topOfTheHill.name)));
      // Never earned by a run at all - it is a lifetime total.
      expect(won, isNot(contains(Award.coinHunter.name)));
    });

    test('earns nothing it did not do', () async {
      final game = await boot();
      // Straight into the wall without playing: the only thing true of this
      // run is that it happened.
      game.startRun();
      playUntilOut(game);
      await Future<void>.delayed(Duration.zero);

      expect(Prefs.awardsWon, <String>{Award.firstRun.name});
    });

    test('marks nothing as synced while signed out', () async {
      final game = await boot();
      // Earned and sent are different questions. A child playing signed out
      // has still won the badge, and it must still be waiting to go up when
      // they eventually sign in.
      game.startRun();
      playWell(game, untilScore: kAwardScoreOne);
      playUntilOut(game);
      await Future<void>.delayed(Duration.zero);

      expect(Prefs.awardsWon, isNotEmpty);
      expect(Prefs.awardsSynced, isEmpty);
    });
  });
}
