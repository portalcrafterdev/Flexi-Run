import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'menu_land.dart';
import 'menu_sky.dart';

/// The menu's own scene: a lit sky, a range of mountains, rolling meadow, and
/// the path the game is run down winding away to a castle.
///
/// Painted here rather than shown through to the live world. The world behind
/// is a running game, and a runner jogging on the spot behind the title reads
/// as something left switched on by mistake. This is a picture of the same
/// place, with the character standing still in it.
///
/// Two layers, each in its own repaint boundary. The scenery is a good deal of
/// path work and is painted once; only the handful of things that move are
/// redrawn per frame. Painting the lot every frame is how a menu ends up
/// costing more than the game.
class MenuBackground extends StatefulWidget {
  const MenuBackground({super.key});

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground>
    with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kMenuDriftSeconds),
  )..repeat();

  /// A second, far slower clock. The balloons bob on a seven second loop; a
  /// cloud sharing it would tear across the sky. One controller cannot serve
  /// both, because it is the loop length that sets the speed.
  late final AnimationController _sky = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kMenuCloudSeconds),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    _sky.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _SkyPainter(), size: Size.infinite),
          ),
        ),
        // Between the sky and the land, which is where clouds belong. Putting
        // them on the drift layer would be fewer boundaries and would look
        // identical today - right up until a cloud is moved low enough to
        // reach a mountain, and then it is in front of it.
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _sky,
              builder: (_, _) => CustomPaint(
                painter: _CloudPainter(_sky.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _LandPainter(), size: Size.infinite),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (_, _) => CustomPaint(
                painter: _DriftPainter(_drift.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything above the horizon that never moves.
class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintSky(canvas, size);
    paintSunburst(canvas, size);
    paintSun(canvas, size);
    paintSparkles(canvas, size);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// The clouds, crossing the sky.
class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.phase);

  /// 0 to 1, one lap of the sky.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) => paintClouds(canvas, size, phase);

  @override
  bool shouldRepaint(_CloudPainter old) => old.phase != phase;
}

/// Everything below the horizon that never moves. Still the bulk of the paint
/// work, and still painted exactly once.
class _LandPainter extends CustomPainter {
  const _LandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintMountains(canvas, size);
    paintMeadow(canvas, size);
    paintCastle(canvas, size);
    paintTrees(canvas, size);
    // Over the rises, so the road is one continuous thing rather than three
    // stripes that happen to line up.
    paintPath(canvas, size);
    paintFlowers(canvas, size);
  }

  @override
  bool shouldRepaint(_LandPainter old) => false;
}

/// The few things that do: balloons, the drifting shapes, and the corner
/// shading laid over the top of everything.
class _DriftPainter extends CustomPainter {
  const _DriftPainter(this.phase);

  /// 0 to 1, one full bob.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, spot) in kMenuBalloons.indexed) {
      final lift = sin((phase + i * 0.4) * 2 * pi) * kMenuBalloonBob;
      paintBalloon(canvas, size, spot, lift);
    }
    // Last, over everything: it is the light in the room, not scenery.
    _vignette(canvas, size);
  }

  /// Corners taken down, so the middle of the picture is the brightest part of
  /// it and the cards read against a settled background rather than a wash.
  void _vignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.45),
          size.width * 0.62,
          const <Color>[Color(0x00000000), kMenuVignette],
          const <double>[kMenuVignetteStart, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_DriftPainter old) => old.phase != phase;
}
