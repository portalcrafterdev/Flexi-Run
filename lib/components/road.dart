import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/art_canvas.dart';
import '../core/constants.dart';
import '../game/projection.dart';

/// The grass and the path running away to the horizon.
///
/// Drawn procedurally rather than from a sprite: the path is a perspective
/// wedge and its rungs have to be re-projected every frame, which is exactly
/// what makes the ground read as rushing toward the runner.
class Road extends PositionComponent {
  Road() : super(priority: kPrioRoad);

  /// How far the rungs have travelled, wrapped to one rung spacing.
  double _offset = 0;

  void advance(double speed, double dt) {
    _offset = (_offset + speed * dt) % kStripeSpacing;
  }

  void reset() => _offset = 0;

  @override
  void render(Canvas canvas) {
    // Ground colour runs from washed out at the horizon to saturated at the
    // camera. A single flat green is the strongest tell that a scene is flat.
    final ground = Rect.fromLTRB(0, kHorizonY, kWorldW, kWorldH);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = ui.Gradient.linear(
          ground.topCenter,
          ground.bottomCenter,
          const <Color>[kGrassFarColor, kGrassNearColor],
        ),
    );

    final wedge = _wedge();
    canvas
      ..drawPath(
        wedge,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(kVanishX, kHorizonY),
            Offset(kNearLaneX, kWorldH),
            const <Color>[kPathFarColor, kPathNearColor],
          ),
      )
      ..save()
      ..clipPath(wedge);
    _rungs(canvas);
    canvas
      ..restore()
      ..drawPath(wedge, strokeWith(kPathEdgeColor, kRoadEdgeWidth))
      // Haze pooling where the ground meets the sky, so the path fades into
      // the distance instead of ending at a hard line.
      ..drawRect(
        Rect.fromLTRB(0, kHorizonY, kWorldW, kHorizonY + kHazeDepth),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, kHorizonY),
            Offset(0, kHorizonY + kHazeDepth),
            const <Color>[kHazeColor, Color(0x00EAF7FF)],
          ),
      );
  }

  /// The path itself: a wedge from the vanishing point out to the near edge.
  Path _wedge() {
    final y = groundYAt(kMinDrawZ);
    return Path()
      ..moveTo(kVanishX, kHorizonY)
      ..lineTo(sideXAt(-kRoadHalfWidth, kMinDrawZ), y)
      ..lineTo(sideXAt(kRoadHalfWidth, kMinDrawZ), y)
      ..close();
  }

  /// Transverse bands marching toward the camera. Their spacing on screen
  /// compresses toward the horizon on its own, because they are projected.
  void _rungs(Canvas canvas) {
    final paint = fillWith(kPathDarkColor);
    for (var i = 0; i < kRungCount; i++) {
      final near = i * kStripeSpacing + _offset + kMinDrawZ;
      final far = near + kStripeSpacing * kStripeDuty;
      if (far <= kMinDrawZ) continue;
      canvas.drawPath(_band(near, far), paint);
    }
  }

  Path _band(double nearZ, double farZ) {
    final yNear = groundYAt(nearZ);
    final yFar = groundYAt(farZ);
    return Path()
      ..moveTo(sideXAt(-kRoadHalfWidth, nearZ), yNear)
      ..lineTo(sideXAt(kRoadHalfWidth, nearZ), yNear)
      ..lineTo(sideXAt(kRoadHalfWidth, farZ), yFar)
      ..lineTo(sideXAt(-kRoadHalfWidth, farZ), yFar)
      ..close();
  }
}
