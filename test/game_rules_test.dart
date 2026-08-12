import 'dart:math';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/components/clouds.dart';
import 'package:flexirun/components/player.dart';
import 'package:flexirun/core/art_canvas.dart';
import 'package:flexirun/components/wall.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/core/lane.dart';
import 'package:flexirun/core/shape_kind.dart';
import 'package:flexirun/game/shape_shifter_game.dart';

const _frame = 1 / 60;
const _maxFrames = 3000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  /// One frame of the loop, component tree and all.
  void step(ShapeShifterGame game, [double dt = _frame]) => game.update(dt);

  Wall nextWall(ShapeShifterGame game) {
    for (var i = 0; i < _maxFrames; i++) {
      final pending = game.walls.where((wall) => !wall.resolved);
      if (pending.isNotEmpty) return pending.first;
      step(game);
    }
    fail('no wall arrived');
  }

  void runUntilResolved(ShapeShifterGame game, Wall wall) {
    for (var i = 0; i < _maxFrames && !wall.resolved; i++) {
      step(game);
    }
    expect(wall.resolved, isTrue, reason: 'wall never reached the player');
  }

  ShapeKind otherThan(ShapeKind kind) =>
      ShapeKind.values.firstWhere((value) => value != kind);

  Lane otherLaneThan(Lane lane) =>
      Lane.values.firstWhere((value) => value != lane);

  /// Lines the runner up with a wall: right shape, right lane.
  void lineUpWith(ShapeShifterGame game, Wall wall) {
    game
      ..morph(wall.shape)
      ..moveToLane(wall.lane);
  }

  /// Clears one wall cleanly and returns it.
  Wall passCleanly(ShapeShifterGame game) {
    final wall = nextWall(game);
    lineUpWith(game, wall);
    runUntilResolved(game, wall);
    return wall;
  }

  group('geometry', () {
    test('the hole centre lands on the runner\'s body', () {
      // Wall base on the ground, hole measured up from it.
      expect(kNearGroundY - (kWallH - kHoleLocalY), kPlayerCentreY);
    });

    test('the runner stands on the ground rather than floating', () {
      expect(kPlayerCentreY + kPlayerHalf + kLegLength, kNearGroundY);
    });

    test('the hole is more forgiving than the runner is wide', () {
      expect(kHoleHalf, greaterThan(kPlayerHalf));
    });

    test('the wall reaches the ground below the hole', () {
      expect(kHoleLocalY + kHoleHalf, lessThan(kWallH));
    });

    test('a wall spans wider than the path it blocks', () {
      expect(kWallW / 2, greaterThan(kRoadHalfWidth));
    });
  });

  group('render order', () {
    test('an approaching wall is behind the runner', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final wall = game.walls.single;
      expect(wall.z, greaterThan(kWallHitZ));
      expect(game.player.priority, kPrioPlayer);
      expect(wall.priority, lessThan(game.player.priority));
    });

    test('a wall reaching the runner flips in front of it', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final wall = game.walls.single;
      // Walk it in to the runner's own plane.
      wall
        ..z = kWallHitZ
        ..project();

      expect(
        wall.priority,
        greaterThan(game.player.priority),
        reason: 'the bricks must occlude the runner as it goes through',
      );
    });

    test('the runner holds its lane until asked to move', () async {
      final game = await boot();
      game.startRun();
      for (var i = 0; i < 300; i++) {
        step(game);
      }

      expect(game.player.position.x, kNearLaneX);
      expect(game.player.position.y, kNearGroundY);
    });

    test('a wall grows as it approaches', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final wall = game.walls.single;
      final farWidth = wall.size.x;
      wall
        ..z = kWallHitZ
        ..project();

      expect(wall.size.x, greaterThan(farWidth * 3));
      expect(wall.size.x, closeTo(kWallW, 0.001));
    });
  });

  group('collision', () {
    test('a matching shape scores and costs nothing', () async {
      final game = await boot();
      game.startRun();
      passCleanly(game);

      expect(game.score.value, kScorePerWall);
      expect(game.lives.value, kLives);
      expect(game.state, GameState.running);
    });

    test('a wrong shape costs a life', () async {
      final game = await boot();
      game.startRun();
      final wall = nextWall(game);
      // Right lane, wrong shape: the shape alone is what fails here.
      game
        ..moveToLane(wall.lane)
        ..morph(otherThan(wall.shape));
      runUntilResolved(game, wall);

      expect(game.lives.value, kLives - 1);
      expect(game.score.value, 0);
      expect(game.state, GameState.hit);
    });

    test('each wall is resolved exactly once', () async {
      final game = await boot();
      game.startRun();
      final wall = passCleanly(game);
      final scoreAfter = game.score.value;

      for (var i = 0; i < 60; i++) {
        step(game);
      }
      expect(wall.resolved, isTrue);
      expect(game.score.value, scoreAfter);
    });

    test('a tap inside the forgiveness window still counts', () async {
      final game = await boot();
      game.startRun();
      final wall = nextWall(game);
      game
        ..moveToLane(wall.lane)
        ..morph(otherThan(wall.shape));

      // Ride into the wall wearing the wrong shape.
      for (var i = 0; i < _maxFrames && wall.graceT == 0; i++) {
        step(game);
      }
      expect(
        wall.resolved,
        isFalse,
        reason: 'the verdict should still be open',
      );

      // Late tap, well inside kForgiveSeconds.
      game.morph(wall.shape);
      step(game);

      expect(wall.resolved, isTrue);
      expect(game.lives.value, kLives);
      expect(game.score.value, kScorePerWall);
    });

    test('a tap after the forgiveness window is too late', () async {
      final game = await boot();
      game.startRun();
      final wall = nextWall(game);
      game
        ..moveToLane(wall.lane)
        ..morph(otherThan(wall.shape));
      runUntilResolved(game, wall);

      expect(game.lives.value, kLives - 1);
    });
  });

  group('lanes', () {
    test('a run starts in the middle', () async {
      final game = await boot();
      game.startRun();

      expect(game.player.lane, kStartLane);
      expect(game.activeLane.value, kStartLane);
    });

    test('stepping moves one track at a time and stops at the edges', () async {
      final game = await boot();
      game.startRun();

      game.stepLane(-1);
      expect(game.player.lane, Lane.left);
      game.stepLane(-1);
      expect(game.player.lane, Lane.left, reason: 'the left edge is a wall');

      game
        ..stepLane(1)
        ..stepLane(1);
      expect(game.player.lane, Lane.right);
      game.stepLane(1);
      expect(game.player.lane, Lane.right, reason: 'the right edge is a wall');
    });

    test('the right shape in the wrong lane still costs a life', () async {
      final game = await boot();
      game.startRun();
      final wall = nextWall(game);
      game
        ..morph(wall.shape)
        ..moveToLane(otherLaneThan(wall.lane));
      runUntilResolved(game, wall);

      expect(game.lives.value, kLives - 1);
      expect(game.score.value, 0);
    });

    test('a lane change inside the forgiveness window still counts', () async {
      final game = await boot();
      game.startRun();
      final wall = nextWall(game);
      // Right shape, wrong lane, corrected late.
      game
        ..morph(wall.shape)
        ..moveToLane(otherLaneThan(wall.lane));

      for (var i = 0; i < _maxFrames && wall.graceT == 0; i++) {
        step(game);
      }
      expect(wall.resolved, isFalse);

      game.moveToLane(wall.lane);
      step(game);

      expect(wall.resolved, isTrue);
      expect(game.lives.value, kLives);
      expect(game.score.value, kScorePerWall);
    });

    test('the runner slides across to the lane it is put in', () async {
      final game = await boot();
      game.startRun();
      final startX = game.player.position.x;

      game.moveToLane(Lane.right);
      for (var i = 0; i < 60; i++) {
        step(game);
      }

      expect(game.player.position.x, greaterThan(startX));
      expect(game.player.position.x, closeTo(kNearLaneX + kLaneOffset, 0.001));
    });

    test('holes are punched over every lane', () async {
      final game = await boot();
      game.startRun();
      final seen = <Lane>{};

      for (var i = 0; i < 400 && seen.length < Lane.values.length; i++) {
        final wall = nextWall(game);
        seen.add(wall.lane);
        lineUpWith(game, wall);
        runUntilResolved(game, wall);
      }

      expect(seen, Lane.values.toSet());
    });
  });

  group('shield', () {
    test('is granted every five clean passes', () async {
      final game = await boot();
      game.startRun();

      for (var i = 0; i < kShieldEveryPasses - 1; i++) {
        passCleanly(game);
        expect(game.shielded.value, isFalse);
      }
      passCleanly(game);

      expect(game.shielded.value, isTrue);
      expect(game.player.hasShield, isTrue);
    });

    test('eats the next wall whatever shape it is', () async {
      final game = await boot();
      game.startRun();
      for (var i = 0; i < kShieldEveryPasses; i++) {
        passCleanly(game);
      }
      final scoreBefore = game.score.value;

      final wall = nextWall(game);
      game.morph(otherThan(wall.shape));
      runUntilResolved(game, wall);

      expect(game.lives.value, kLives);
      expect(game.score.value, scoreBefore + kScorePerWall);
      expect(game.shielded.value, isFalse);
      expect(game.state, GameState.running);
    });
  });

  group('run lifecycle', () {
    test('runs out of lives and remembers the score', () async {
      final game = await boot();
      game.startRun();

      var crashes = 0;
      while (game.state != GameState.gameOver && crashes < kLives + 2) {
        final wall = nextWall(game);
        game.morph(otherThan(wall.shape));
        runUntilResolved(game, wall);
        crashes++;
        // Sit out the freeze frame and the invulnerable blink.
        for (var i = 0; i < 120; i++) {
          step(game);
        }
      }

      expect(crashes, kLives);
      expect(game.state, GameState.gameOver);
      expect(game.lives.value, 0);
      expect(game.highScore.value, game.score.value);
    });

    test('starting again clears the board', () async {
      final game = await boot();
      game.startRun();
      passCleanly(game);
      game.startRun();

      expect(game.score.value, 0);
      expect(game.lives.value, kLives);
      expect(game.walls, isEmpty);
      expect(game.player.shape, kStartShape);
      expect(game.state, GameState.running);
    });

    test('the menu drifts but never spawns a wall', () async {
      final game = await boot();
      expect(game.state, GameState.menu);
      expect(game.speed, kMenuSpeed);

      for (var i = 0; i < 600; i++) {
        step(game);
      }
      expect(game.walls, isEmpty);
    });

    test('morphing is ignored outside a run', () async {
      final game = await boot();
      game.morph(otherThan(kStartShape));

      expect(game.player.shape, kStartShape);
    });
  });

  group('coins', () {
    test('a trail reaches every track', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      // There is gold to chase wherever the runner happens to be standing.
      expect(
        game.coinsInPlay.map((coin) => coin.lane).toSet(),
        Lane.values.toSet(),
      );
    });

    test('a trail arrives ahead of its wall and ends over the hole', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final wall = game.walls.single;
      for (final coin in game.coinsInPlay) {
        expect(
          coin.z,
          lessThan(wall.z),
          reason: 'coins must arrive before the wall they lead to',
        );
      }

      // The rows nearest the wall - the ones arriving last - narrow to the
      // hole's own track, so the trail still walks the runner into place.
      final nearest = game.coinsInPlay.where(
        (coin) => coin.z > wall.z + kCoinLeadZ - kCoinSpacingZ * 1.5,
      );
      expect(nearest, isNotEmpty);
      for (final coin in nearest) {
        expect(coin.lane, wall.lane, reason: 'the trail is the hint');
      }
    });

    // The trail is furthest first, so `last` is the coin that arrives soonest.
    test('a trail is not drawn until it is close enough to see', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      // Laid far up the path, where a coin is a few pixels of glitter.
      for (final coin in game.coinsInPlay) {
        expect(coin.z, greaterThan(kCoinAppearZ));
        expect(coin.opacity, 0);
      }

      final coin = game.coinsInPlay.last
        ..z = kCoinSolidZ
        ..project();
      expect(coin.opacity, 1);
    });

    test('a coin in the runner\'s lane is taken', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final coin = game.coinsInPlay.last;
      game.moveToLane(coin.lane);
      for (var i = 0; i < _maxFrames && !coin.resolved; i++) {
        step(game);
      }

      expect(coin.taken, isTrue);
      expect(game.coins.value, 1);
    });

    test('a whole trail is worth its own length', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final furthest = game.coinsInPlay.first;
      game.moveToLane(furthest.lane);
      for (var i = 0; i < _maxFrames && !furthest.resolved; i++) {
        step(game);
      }

      expect(game.coins.value, kCoinsPerTrail);
    });

    test('a coin in another lane is missed and costs nothing', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final coin = game.coinsInPlay.last;
      game.moveToLane(otherLaneThan(coin.lane));
      for (var i = 0; i < _maxFrames && !coin.resolved; i++) {
        step(game);
      }

      expect(coin.resolved, isTrue);
      expect(coin.taken, isFalse);
      expect(game.lives.value, kLives, reason: 'a missed coin is not a hit');
    });

    test('coins never touch the score', () async {
      final game = await boot();
      game.startRun();
      step(game, 0);

      final coin = game.coinsInPlay.last;
      game.moveToLane(coin.lane);
      for (var i = 0; i < _maxFrames && !coin.resolved; i++) {
        step(game);
      }

      // The score drives the difficulty ramp. If coins paid into it, the wall
      // spacing would tighten several times faster than it is tuned for.
      expect(game.coins.value, greaterThan(0));
      expect(game.score.value, 0);
    });
  });

  group('run cycle', () {
    test('a foot is always planted on the ground', () async {
      final game = await boot();
      game.startRun();

      // Two full strides, sampled finely enough to catch a lift between them.
      for (var i = 0; i < 240; i++) {
        step(game);
        // Going through a hole the runner is deliberately off the ground.
        if (game.player.isTucking) continue;
        expect(
          game.player.lowestFootY,
          closeTo(Player.groundY, 0.5),
          reason: 'the runner lifted off the road at frame $i',
        );
      }
    });

    test('the limbs tuck behind the body to go through a hole', () async {
      final game = await boot();
      game.startRun();
      game.player.squeeze();

      // Past the rise, into the hold.
      for (var i = 0; i < 12; i++) {
        step(game);
      }

      // Behind the body means inside the hole, because the body is the same
      // shape as the hole. Feet below the body would be out in the brick.
      expect(game.player.isTucking, isTrue);
      expect(
        game.player.lowestFootY,
        lessThan(game.player.bodyY),
        reason: 'the feet must be drawn up behind the body while crossing',
      );
    });

    test('the body rides up and down over the stride', () async {
      final game = await boot();
      game.startRun();

      var lowest = double.negativeInfinity;
      var highest = double.infinity;
      for (var i = 0; i < 240; i++) {
        step(game);
        final y = game.player.bodyY;
        lowest = max(lowest, y);
        highest = min(highest, y);
      }

      // Without this the runner slides along at a fixed height, which is the
      // other half of what reads as floating.
      expect(lowest - highest, greaterThan(kRunBobPixels * 0.8));
    });
  });

  group('pause', () {
    test('the pause button is not buried under the tap layer', () {
      // The tap-anywhere layer inside the pad fills the screen, so the pad
      // has to stack below the HUD or the pause button can never be tapped.
      expect(
        Overlays.priorityOf(Overlays.pad),
        lessThan(Overlays.priorityOf(Overlays.hud)),
        reason: 'the pad must render below the HUD',
      );
    });

    test('a paused run ignores taps on the pad behind the panel', () async {
      final game = await boot();
      game.startRun();
      game.requestPause();

      game.morph(otherThan(kStartShape));
      game.stepLane(1);

      expect(game.player.shape, kStartShape);
      expect(game.player.lane, kStartLane);
    });

    test('the pause flag flips both ways, so one button can do both', () async {
      final game = await boot();
      game.startRun();

      expect(game.pauseNotifier.value, isFalse);
      game.requestPause();
      expect(game.pauseNotifier.value, isTrue);
      game.resumePlay();
      expect(game.pauseNotifier.value, isFalse);
    });

    test('the state notifier follows the run, for widgets outside the overlays',
        () async {
      final game = await boot();
      expect(game.stateNotifier.value, GameState.menu);

      game.startRun();
      expect(game.stateNotifier.value, GameState.running);

      game.goToMenu();
      expect(game.stateNotifier.value, GameState.menu);
    });

    test('input comes back when the run is resumed', () async {
      final game = await boot();
      game.startRun();
      game.requestPause();
      game.resumePlay();

      final wanted = otherThan(kStartShape);
      game.morph(wanted);

      expect(game.player.shape, wanted);
    });
  });

  group('scenery', () {
    test('the verge is not lined with the same tree over and over', () async {
      final game = await boot();

      expect(
        game.art.trees.length,
        greaterThan(1),
        reason: 'one silhouette repeated is what makes scenery read as '
            'wallpaper',
      );
      expect(
        game.scenery.map((item) => item.sprite).toSet().length,
        greaterThan(1),
        reason: 'the pool should be drawing on more than one of them',
      );
    });

    test('distance washes scenery toward the sky, and only distance', () {
      expect(hazeAt(0), isNull);
      expect(hazeAt(kSceneryHazeStartZ), isNull);
      expect(hazeAt(kSceneryHazeStartZ + 1), isNotNull);
      // Quantised, so the same filters are reused rather than rebuilt.
      expect(hazeAt(kSceneryHazeFullZ), same(hazeAt(kSceneryHazeFullZ * 2)));
    });

    test('a prop is hazed by where it is, not by what it is', () async {
      final game = await boot();
      final item = game.scenery.first;

      item
        ..z = kSceneryHazeFullZ
        ..project();
      expect(item.paint.colorFilter, isNotNull);

      item
        ..z = 0
        ..project();
      expect(item.paint.colorFilter, isNull);
    });

    test('the cloud band wraps instead of running off the sky', () async {
      final game = await boot();
      final clouds = Clouds(game.art.clouds);

      // Far more drift than a whole tile, in one go.
      clouds.advance(kWorldW * 20 / kCloudDriftFactor, 1);
      clouds.render(Canvas(PictureRecorder()));

      clouds.reset();
      clouds.advance(kWorldW / kCloudDriftFactor, 1);
      clouds.render(Canvas(PictureRecorder()));
    });
  });
}
