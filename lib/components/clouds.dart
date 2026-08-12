import 'dart:ui';

import 'package:flame/components.dart';

import '../core/constants.dart';

/// The cloud band, drifting across the sky.
///
/// Two copies of one tile, laid end to end and scrolled: when the leading copy
/// has moved a full world width the offset wraps and nothing has changed, so
/// the band runs forever. The clouds are painted clear of the tile edges, which
/// is what lets the join go unnoticed.
///
/// Drifts at a fraction of the world speed, because they are the furthest thing
/// in the scene. Weather that keeps pace with the roadside reads as a gale.
class Clouds extends PositionComponent {
  Clouds(this._sprite) : super(priority: kPrioClouds);

  final Sprite _sprite;

  double _offset = 0;

  void advance(double speed, double dt) {
    _offset = (_offset + speed * kCloudDriftFactor * dt) % kWorldW;
  }

  void reset() => _offset = 0;

  @override
  void render(Canvas canvas) {
    final size = Vector2(kWorldW, kCloudBandH);
    for (final x in <double>[-_offset, kWorldW - _offset]) {
      _sprite.render(canvas, position: Vector2(x, kCloudBandY), size: size);
    }
  }
}
