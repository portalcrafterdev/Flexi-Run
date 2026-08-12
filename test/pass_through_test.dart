import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphorun/components/wall.dart';
import 'package:morphorun/core/constants.dart';
import 'package:morphorun/core/lane.dart';
import 'package:morphorun/core/shape_kind.dart';
import 'package:morphorun/game/shape_shifter_game.dart';

// The core visual rule, checked against actual pixels rather than by eye: a
// wall that has reached the runner draws in front of it, the hole is a real
// opening, and the two line up. If any of these break, the game stops reading
// as a pass-through.

const _width = 1280;
const _height = 720;

/// A point on the runner's body that a star hole is too narrow to expose.
/// The body reaches about 89 from the lane; a star hole only reaches about 72.
const _flankOffset = 80;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // At zoom 1 the camera still shifts the world vertically, because it is
  // aimed below the middle of it.
  int toScreenY(double worldY) =>
      (worldY - kCameraCentreY + _height / 2).round();

  final centreX = kNearLaneX.toInt();
  final centreY = toScreenY(kPlayerCentreY);
  final flankX = (kNearLaneX + _flankOffset).toInt();

  Future<ShapeShifterGame> boot() async {
    final game = await initializeGame(ShapeShifterGame.new);
    // One world pixel per image pixel, so world coordinates can be sampled
    // directly.
    game.onGameResize(Vector2(kWorldW, kWorldH));
    // In a run, not on the menu: the menu deliberately has no runner on it.
    game.startRun();
    game.update(0);
    return game;
  }

  Future<ByteData> frame(ShapeShifterGame game) async {
    final recorder = ui.PictureRecorder();
    game.renderTree(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(_width, _height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return data!;
  }

  Color pixel(ByteData data, int x, int y) {
    final i = (y * _width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  // Channels are 0..1, so this is a 25/255 margin.
  bool isRunner(Color c) => c.g > c.r + 0.098 && c.g > c.b + 0.098;

  /// Any part of the barrier: brick, mortar, the lit lip along a course, or
  /// the bevel inside the opening.
  ///
  /// Stated as "warm" rather than as a brick colour because the bricks are
  /// laid individually and jittered, and a five pixel sample can land wholly
  /// inside a mortar joint. Every wall material runs red over green over
  /// blue; the runner and the grass both run green first.
  bool isWall(Color c) => c.r > c.g && c.g > c.b;

  /// True when [test] holds across a small patch, which keeps the assertions
  /// off single stray pixels and off the mortar lines.
  bool patch(ByteData data, int cx, int cy, bool Function(Color) test) {
    for (var y = cy - 2; y <= cy + 2; y++) {
      for (var x = cx - 2; x <= cx + 2; x++) {
        if (!test(pixel(data, x, y))) return false;
      }
    }
    return true;
  }

  Future<Wall> addWall(ShapeShifterGame game, ShapeKind shape, double z) async {
    // The runner starts in the centre lane, so that is where the hole goes.
    final wall = Wall(shape: shape, lane: kStartLane, art: game.art, z: z);
    await game.world.add(wall);
    game.update(0);
    return wall;
  }

  test('the runner is on screen where the test expects it', () async {
    final game = await boot();
    final data = await frame(game);

    expect(
      patch(data, centreX, centreY, isRunner),
      isTrue,
      reason: 'the runner should be visible at the near end of the lane',
    );
    expect(
      patch(data, flankX, centreY, isRunner),
      isTrue,
      reason: "the flank sample must sit on the runner's body",
    );
  });

  test('the hole is a real opening the runner shows through', () async {
    final game = await boot();
    await addWall(game, ShapeKind.circle, kWallHitZ);
    final data = await frame(game);

    expect(
      patch(data, centreX, centreY, isRunner),
      isTrue,
      reason: 'the runner must still be visible inside the hole',
    );
  });

  test('the bricks cut the runner off outside the hole', () async {
    final game = await boot();
    await addWall(game, ShapeKind.star, kWallHitZ);
    final data = await frame(game);

    // The star is narrow at the horizontal, so this flank of the runner is
    // behind bricks even though the runner is drawn there.
    expect(
      patch(data, flankX, centreY, isWall),
      isTrue,
      reason: 'the wall must occlude the runner outside the hole',
    );
    expect(
      patch(data, centreX, centreY, isRunner),
      isTrue,
      reason: 'the centre of the star is still an opening',
    );
  });

  test('a wall still up the path hides nothing', () async {
    final game = await boot();
    await addWall(game, ShapeKind.square, kWallSpawnZ * 0.5);
    final data = await frame(game);

    expect(
      patch(data, centreX, centreY, isRunner),
      isTrue,
      reason: 'an approaching wall draws behind the runner',
    );
  });
}
