import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../core/art_canvas.dart';
import '../core/constants.dart';
import '../core/placeholder_art.dart';
import '../game/projection.dart';

/// The grass and the path running away to the horizon.
///
/// Drawn procedurally rather than from a sprite: the path is a perspective
/// wedge and its rungs have to be re-projected every frame, which is exactly
/// what makes the ground read as rushing toward the runner. The grass is drawn
/// the same way, for the same reason - a field painted once and left alone is
/// wallpaper, however good the painting is.
class Road extends PositionComponent {
  Road(this._art, {Random? random}) : super(priority: kPrioRoad) {
    final rng = random ?? Random(kGroundSeed);
    for (var i = 0; i < kGroundPatchCount; i++) {
      _patches.add(_Patch.random(rng, i));
    }
    for (var i = 0; i < kVergeTuftCount; i++) {
      _tufts.add(_Tuft.random(rng, i));
    }
    _deepStamp = _Stamp(_art.grassPatchDeep, _patches.length);
    _litStamp = _Stamp(_art.grassPatchLit, _patches.length);
    _tuftStamps = <_Stamp>[
      for (final image in _art.vergeTufts) _Stamp(image, _tufts.length),
    ];
  }

  final ArtPack _art;
  final List<_Patch> _patches = <_Patch>[];
  final List<_Tuft> _tufts = <_Tuft>[];

  // Built in the constructor: one batch per image, reused every frame.
  late final _Stamp _deepStamp;
  late final _Stamp _litStamp;
  late final List<_Stamp> _tuftStamps;

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
  /// Stamped from two pre-blurred images, one draw call per tone however many
  /// blotches there are. The blur is baked into the image: applying one here
  /// would allocate an offscreen the size of the field on every frame, which
  /// is what used to cost this game its frame rate.
  void _cover(Canvas canvas) {
    _deepStamp.begin();
    _litStamp.begin();
    for (final patch in _patches) {
      final z = _wrap(patch.basisZ - _grassScroll, kGroundPatchSpanZ);
      if (z > kGroundPatchCullZ) continue;
      // Blotches shrink away toward the horizon rather than fading, because
      // one batch of stamps carries one colour between them all.
      final fade =
          ((kGroundPatchCullZ - z) / (kGroundPatchCullZ - kGroundPatchFadeZ))
              .clamp(0.0, 1.0);
      final scale = patch.jitter * scaleAt(z) * fade;
      final w = kGroundPatchW * scale;
      final x = sideXAt(patch.lateral, z);
      if (w < 1 || x + w < 0 || x - w > kWorldW) continue;

      (patch.lit ? _litStamp : _deepStamp).at(x, groundYAt(z), scale);
    }
    _deepStamp.render(canvas);
    _litStamp.render(canvas);
  }

  /// Grass along both edges of the path, stamped the same way.
  void _verge(Canvas canvas) {
    for (final stamp in _tuftStamps) {
      stamp.begin();
    }
    for (final tuft in _tufts) {
      final z = _wrap(tuft.basisZ - _vergeScroll, kVergeTuftSpanZ);
      if (z > kVergeTuftCullZ) continue;
      final x = sideXAt(tuft.lateral, z);
      if (x < -kVergeTuftW || x > kWorldW + kVergeTuftW) continue;

      final grow = ((kVergeTuftCullZ - z) / kVergeTuftGrowZ).clamp(0.0, 1.0);
      _tuftStamps[tuft.variant].at(
        x,
        groundYAt(z),
        min(scaleAt(z), kVergeMaxScale) * grow,
        bottomAnchored: true,
      );
    }
    for (final stamp in _tuftStamps) {
      stamp.render(canvas);
    }
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

/// A batch of one image, stamped many times in a single draw call.
///
/// The transform and source buffers are allocated once and rewritten in place
/// every frame, so drawing the whole ground cover allocates nothing at all.
/// Entries left over from a shorter frame are zeroed, which draws nothing.
class _Stamp {
  _Stamp(this._image, int capacity)
    : _transforms = Float32List(capacity * 4),
      _sources = Float32List(capacity * 4) {
    // Every stamp uses the whole image, so the source rectangles never change.
    for (var i = 0; i < capacity; i++) {
      _sources[i * 4 + 2] = _image.width.toDouble();
      _sources[i * 4 + 3] = _image.height.toDouble();
    }
  }

  final ui.Image _image;
  final Float32List _transforms;
  final Float32List _sources;
  final Paint _paint = Paint();

  int _count = 0;

  void begin() => _count = 0;

  /// Places the image centred on [x], [y] at [scale]. With [bottomAnchored]
  /// the image sits on that point instead, which is what a tuft of grass
  /// growing out of the ground wants.
  void at(double x, double y, double scale, {bool bottomAnchored = false}) {
    if (_count * 4 >= _transforms.length) return;
    final anchorX = _image.width / 2;
    final anchorY = bottomAnchored ? _image.height.toDouble() : _image.height / 2;
    final i = _count++ * 4;
    // scos, ssin, tx, ty. No rotation, so ssin is zero and the translation is
    // just the anchor scaled out of the position.
    _transforms[i] = scale;
    _transforms[i + 1] = 0;
    _transforms[i + 2] = x - scale * anchorX;
    _transforms[i + 3] = y - scale * anchorY;
  }

  void render(Canvas canvas) {
    for (var i = _count * 4; i < _transforms.length; i++) {
      _transforms[i] = 0;
    }
    canvas.drawRawAtlas(
      _image,
      _transforms,
      _sources,
      null,
      null,
      null,
      _paint,
    );
  }
}

/// A blotch of grass, at a fixed place in the field.
class _Patch {
  const _Patch({
    required this.basisZ,
    required this.lateral,
    required this.jitter,
    required this.lit,
  });

  factory _Patch.random(Random rng, int index) {
    final side = index.isEven ? -1.0 : 1.0;
    return _Patch(
      // Spread evenly along the span, then nudged, so the field is never
      // clumped at one depth and never in a visible line either.
      basisZ:
          kGroundPatchSpanZ * (index + rng.nextDouble()) / kGroundPatchCount,
      lateral:
          side *
          (kGroundPatchNear +
              rng.nextDouble() * (kGroundPatchFar - kGroundPatchNear)),
      jitter: 1 + (rng.nextDouble() - 0.5) * kGroundPatchJitter,
      lit: rng.nextBool(),
    );
  }

  final double basisZ;
  final double lateral;

  /// How far this one varies from the drawn size. One number, not two: the
  /// stamp scales uniformly, so the blotch keeps its shape.
  final double jitter;

  final bool lit;
}

/// A clump of blades on one verge.
class _Tuft {
  const _Tuft({
    required this.basisZ,
    required this.lateral,
    required this.variant,
  });

  factory _Tuft.random(Random rng, int index) {
    final side = index.isEven ? -1.0 : 1.0;
    return _Tuft(
      basisZ: kVergeTuftSpanZ * (index + rng.nextDouble()) / kVergeTuftCount,
      lateral: side * (kRoadHalfWidth + rng.nextDouble() * kVergeTuftBand),
      variant: rng.nextInt(kVergeTuftVariants),
    );
  }

  final double basisZ;
  final double lateral;

  /// Which of the drawn clumps this one is, so the verge is not one shape
  /// repeated down the whole path.
  final int variant;
}
