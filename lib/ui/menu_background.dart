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
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kMenuDriftSeconds),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _ScenePainter(), size: Size.infinite),
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

/// Everything that never moves.
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintSky(canvas, size);
    paintSunburst(canvas, size);
    paintSun(canvas, size);
    paintSparkles(canvas, size);
    paintClouds(canvas, size);
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
  bool shouldRepaint(_ScenePainter old) => false;
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
