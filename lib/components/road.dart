import 'dart:math';
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
/// what makes the ground read as rushing toward the runner. The grass is drawn
/// the same way, for the same reason - a field painted once and left alone is
/// wallpaper, however good the painting is.
class Road extends PositionComponent {
  Road({Random? random}) : super(priority: kPrioRoad) {
    final rng = random ?? Random(kGroundSeed);
    for (var i = 0; i < kGroundPatchCount; i++) {
      _patches.add(_Patch.random(rng, i));
    }
    for (var i = 0; i < kVergeTuftCount; i++) {
      _tufts.add(_Tuft.random(rng, i));
    }
  }

  final List<_Patch> _patches = <_Patch>[];
  final List<_Tuft> _tufts = <_Tuft>[];

  /// How far the rungs have travelled, wrapped to one rung spacing.
  double _offset = 0;

  /// The same for the ground cover, which wraps over its own much longer span.
  double _grassScroll = 0;
  double _vergeScroll = 0;

  void advance(double speed, double dt) {
    final travelled = speed * dt;
    _offset = (_offset + travelled) % kStripeSpacing;
    _grassScroll = (_grassScroll + travelled) % kGroundPatchSpanZ;
    _vergeScroll = (_vergeScroll + travelled) % kVergeTuftSpanZ;
  }

  void reset() {
    _offset = 0;
    _grassScroll = 0;
    _vergeScroll = 0;
  }

  @override
  void render(Canvas canvas) {
    // Ground colour runs from washed out at the horizon to saturated at the
    // camera. A single flat green is the strongest tell that a scene is flat.
    //
    // Taken past the bottom of the virtual screen on purpose: the camera is
    // aimed below the middle of the world, so a tall display sees further down
    // than kWorldH and would otherwise find a strip of nothing under the grass.
    final ground = Rect.fromLTRB(0, kHorizonY, kWorldW, groundYAt(kMinDrawZ));
    canvas.drawRect(
      ground,
      Paint()
        // Anchored to the bottom of the virtual screen, not to the rect: the
        // rect runs past it, and the ramp should still finish where the
        // designed frame does.
        ..shader = ui.Gradient.linear(
          const Offset(0, kHorizonY),
          const Offset(0, kWorldH),
          const <Color>[kGrassFarColor, kGrassMidColor, kGrassNearColor],
          const <double>[0, kGrassMidStop, 1],
        ),
    );
    _cover(canvas);

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
      ..drawPath(wedge, strokeWith(kPathEdgeColor, kRoadEdgeWidth));
    // Blades last, so they fringe over the edge of the path instead of being
    // cut off by it. Grass grows across a verge; it does not stop at a line.
    _verge(canvas);
    // Haze pooling where the ground meets the sky, so the path fades into the
    // distance instead of ending at a hard line.
    canvas.drawRect(
      Rect.fromLTRB(0, kHorizonY, kWorldW, kHorizonY + kHazeDepth),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, kHorizonY),
          Offset(0, kHorizonY + kHazeDepth),
          const <Color>[kHazeColor, Color(0x00EAF7FF)],
        ),
    );
  }

  /// Patches of longer and shorter grass either side of the path. Projected
  /// and scrolled like everything else, so the field moves.
  ///
  /// Both tones go into one path each and are blurred as a whole, which is two
  /// draw calls for the entire field. Blurring them individually would be
  /// fifty-odd, and a blur is the most expensive thing on the frame.
  void _cover(Canvas canvas) {
    final deep = Path();
    final lit = Path();
    for (final patch in _patches) {
      final z = _wrap(patch.basisZ - _grassScroll, kGroundPatchSpanZ);
      if (z > kGroundPatchCullZ) continue;
      final s = scaleAt(z);
      // Patches shrink away toward the horizon rather than fading, because a
      // shared blurred path cannot carry a per-patch alpha.
      final fade =
          ((kGroundPatchCullZ - z) / (kGroundPatchCullZ - kGroundPatchFadeZ))
              .clamp(0.0, 1.0);
      final w = patch.w * s * fade;
      final x = sideXAt(patch.lateral, z);
      if (w < 1 || x + w < 0 || x - w > kWorldW) continue;

      (patch.lit ? lit : deep).addOval(
        Rect.fromCenter(
          center: Offset(x, groundYAt(z)),
          width: w,
          height: patch.h * s * fade,
        ),
      );
    }

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kGroundPatchBlur);
    canvas
      ..drawPath(deep, paint..color = kGrassPatchDeepColor)
      ..drawPath(lit, paint..color = kGrassPatchLitColor);
  }

  /// Grass along both edges of the path. Every blade goes into one of two
  /// paths and the whole verge is two draw calls, however many blades it has.
  void _verge(Canvas canvas) {
    final deep = Path();
    final lit = Path();
    for (final tuft in _tufts) {
      final z = _wrap(tuft.basisZ - _vergeScroll, kVergeTuftSpanZ);
      if (z > kVergeTuftCullZ) continue;
      final s = min(scaleAt(z), kVergeMaxScale);
      final grow = ((kVergeTuftCullZ - z) / kVergeTuftGrowZ).clamp(0.0, 1.0);
      final x = sideXAt(tuft.lateral, z);
      if (x < -kVergeBladeH || x > kWorldW + kVergeBladeH) continue;

      final y = groundYAt(z);
      for (var i = 0; i < kVergeBlades; i++) {
        _blade(
          tuft.lit[i] ? lit : deep,
          Offset(x + tuft.dx[i] * s, y),
          kVergeBladeH * tuft.height[i] * s * grow,
          tuft.lean[i] * s,
          kVergeBladeW * s,
        );
      }
    }
    canvas
      ..drawPath(deep, fillWith(kVergeBladeColor))
      ..drawPath(lit, fillWith(kVergeBladeLitColor));
  }

  /// One tapered blade, appended to [into]. Wide at the root and pointed at
  /// the tip: a constant width blade reads as wire.
  static void _blade(
    Path into,
    Offset root,
    double height,
    double lean,
    double half,
  ) {
    into
      ..moveTo(root.dx - half, root.dy)
      ..quadraticBezierTo(
        root.dx - half * 0.3 + lean * 0.4,
        root.dy - height * 0.6,
        root.dx + lean,
        root.dy - height,
      )
      ..quadraticBezierTo(
        root.dx + half + lean * 0.4,
        root.dy - height * 0.55,
        root.dx + half,
        root.dy,
      )
      ..close();
  }

  /// Brings a scrolled depth back into the draw range.
  static double _wrap(double z, double span) =>
      (z % span + span) % span + kMinDrawZ;

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

/// A blotch of grass, at a fixed place in the field.
class _Patch {
  const _Patch({
    required this.basisZ,
    required this.lateral,
    required this.w,
    required this.h,
    required this.lit,
  });

  factory _Patch.random(Random rng, int index) {
    final side = index.isEven ? -1.0 : 1.0;
    final jitter = 1 + (rng.nextDouble() - 0.5) * kGroundPatchJitter;
    return _Patch(
      // Spread evenly along the span, then nudged, so the field is never
      // clumped at one depth and never in a visible line either.
      basisZ:
          kGroundPatchSpanZ * (index + rng.nextDouble()) / kGroundPatchCount,
      lateral:
          side *
          (kGroundPatchNear +
              rng.nextDouble() * (kGroundPatchFar - kGroundPatchNear)),
      w: kGroundPatchW * jitter,
      h: kGroundPatchH * jitter,
      lit: rng.nextBool(),
    );
  }

  final double basisZ;
  final double lateral;
  final double w;
  final double h;
  final bool lit;
}

/// A clump of blades on one verge.
class _Tuft {
  const _Tuft({
    required this.basisZ,
    required this.lateral,
    required this.dx,
    required this.height,
    required this.lean,
    required this.lit,
  });

  factory _Tuft.random(Random rng, int index) {
    final side = index.isEven ? -1.0 : 1.0;
    return _Tuft(
      basisZ: kVergeTuftSpanZ * (index + rng.nextDouble()) / kVergeTuftCount,
      lateral: side * (kRoadHalfWidth + rng.nextDouble() * kVergeTuftBand),
      dx: <double>[
        for (var i = 0; i < kVergeBlades; i++)
          (rng.nextDouble() - 0.5) * kVergeBladeH * 0.5,
      ],
      height: <double>[
        for (var i = 0; i < kVergeBlades; i++) 0.6 + rng.nextDouble() * 0.6,
      ],
      lean: <double>[
        for (var i = 0; i < kVergeBlades; i++)
          (rng.nextDouble() - 0.5) * kVergeBladeLean,
      ],
      lit: <bool>[for (var i = 0; i < kVergeBlades; i++) rng.nextBool()],
    );
  }

  final double basisZ;
  final double lateral;
  final List<double> dx;
  final List<double> height;
  final List<double> lean;
  final List<bool> lit;
}
