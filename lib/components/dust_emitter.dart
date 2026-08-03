import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../core/constants.dart';

/// Puffs kicked up under the runner's feet.
///
/// Sits one layer under the runner, and the puffs drift outward and toward
/// the camera, which is the direction the ground is travelling.
class DustEmitter extends PositionComponent {
  DustEmitter()
    : super(
        position: Vector2(kNearLaneX, kNearGroundY),
        priority: kPrioDust,
      );

  final Random _rng = Random();
  double _next = 0;

  /// Called from the game loop so the puffs inherit the current world speed.
  void emit(double speed, double dt) {
    _next -= dt;
    if (_next > 0) return;
    _next = kDustInterval;

    final radius = kDustRadius * (0.6 + _rng.nextDouble() * 0.8);
    final drift = (_rng.nextDouble() - 0.5) * 2 * kDustSpread;
    add(
      ParticleSystemComponent(
        particle: AcceleratedParticle(
          lifespan: kDustLifespan,
          speed: Vector2(
            drift,
            kDustRise * (0.6 + _rng.nextDouble()) + speed * kDustSpeedShare,
          ),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final left = 1 - particle.progress;
              canvas.drawCircle(
                Offset.zero,
                radius * (0.6 + particle.progress * 1.2),
                Paint()..color = kDustColor.withValues(alpha: left * 0.75),
              );
            },
          ),
        ),
      ),
    );
  }
}
