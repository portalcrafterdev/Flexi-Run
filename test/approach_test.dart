import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/projection.dart';
import 'package:flexirun/game/shape_shifter_game.dart';

// Seeing a wall coming.
//
// The complaint was that walls are not there in the distance - they turn up
// once you have already run some way. What fixes that is not making them
// bigger when they appear but making them appear sooner, so these are about
// how long a wall is on screen before it has to be answered, and about the
// draw order holding all the way out to the horizon.

const _frame = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  group('the approach', () {
    test('a wall is on screen for several seconds before it arrives', () async {
      final game = await boot();
      game.startRun();
      game.update(_frame);

      expect(game.walls, isNotEmpty, reason: 'a run opens with a wall coming');
      final seconds = kWallSpawnZ / game.speed;
      // Five seconds was the old value and was the thing being complained
      // about. This is the whole of the fix, so it is the thing to pin.
      expect(seconds, greaterThan(6.5));
    });

    test('walls spawn far enough back to read as distant', () async {
      // Small, near the horizon. If a wall arrives already large it has not
      // approached, it has appeared.
      expect(scaleAt(kWallSpawnZ), lessThan(0.15));
      expect(
        groundYAt(kWallSpawnZ) - kHorizonY,
        lessThan((kNearGroundY - kHorizonY) * 0.15),
      );
    });

    test('the runner is given a real runway after a revive', () async {
      final game = await boot();
      game.startRun();
      for (var i = 0; i < 60000 && game.state != GameState.gameOver; i++) {
        game.update(_frame);
      }
      game.reviveWithExtraLife();

      // Nothing nearer than the clear depth. This used to assert nothing at
      // all: walls spawned nearer than the clear depth, so the list was always
      // empty and the loop never ran.
      expect(kReviveClearZ, lessThan(kWallSpawnZ), reason: 'or this is vacuous');
      for (final wall in game.walls) {
        expect(wall.z, greaterThan(kReviveClearZ));
      }
      expect(kReviveClearZ / game.speed, greaterThan(4));
    });
  });

  group('draw order', () {
    test('sorts everything from the furthest prop to the runner', () {
      // Measured from the scenery, which starts further back than the walls.
      // Measured from the wall spawn instead, everything beyond it collapsed
      // to one priority and a far tree and a new wall had no order at all.
      expect(kDepthPriorityFarZ, greaterThanOrEqualTo(kScenerySpawnZ));
      expect(kDepthPriorityFarZ, greaterThanOrEqualTo(kWallSpawnZ));

      final far = depthPriority(kScenerySpawnZ);
      final mid = depthPriority(kWallSpawnZ);
      final near = depthPriority(1.0);
      expect(far, lessThan(mid));
      expect(mid, lessThan(near));
    });

    test('the whole depth range fits inside its band', () {
      // The step is derived from the range and the band, so a change to either
      // cannot quietly push the far end past the clamp and flatten the sort.
      // Right at the runner's plane it reaches the top of the band and no
      // further, which is what "the step is derived from the range" buys: the
      // far end lands exactly on the clamp instead of piling up behind it.
      expect(
        depthPriority(1.0),
        lessThanOrEqualTo(kPrioFarBase + kPrioFarSpan),
      );
      expect(depthPriority(kDepthPriorityFarZ), kPrioFarBase);
      // And the far band still ends below everything drawn over it.
      expect(kPrioFarBase + kPrioFarSpan, lessThan(kPrioDust));
    });

    test('a wall that has passed the runner draws over it', () {
      // The rule the whole pass-through depends on.
      expect(depthPriority(-1.0), greaterThan(kPrioPlayer));
      expect(depthPriority(1.0), lessThan(kPrioPlayer));
    });
  });
}
