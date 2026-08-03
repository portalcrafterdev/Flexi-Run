import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../core/constants.dart';

final _rng = Random();

/// Sparkles for a clean pass through the hole.
ParticleSystemComponent sparkleBurst(Vector2 at) {
  return ParticleSystemComponent(
    position: at,
    priority: kPrioBurst,
    particle: Particle.generate(
      count: kSparkleCount,
      lifespan: kSparkleLifespan,
      generator: (_) {
        final angle = _rng.nextDouble() * 2 * pi;
        final speed = kSparkleSpeed * (0.4 + _rng.nextDouble() * 0.6);
        return AcceleratedParticle(
          speed: Vector2(cos(angle), sin(angle))..scale(speed),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final left = 1 - particle.progress;
              canvas.drawCircle(
                Offset.zero,
                kSparkleRadius * left,
                Paint()..color = kSparkleColor.withValues(alpha: left),
              );
            },
          ),
        );
      },
    ),
  );
}

/// Brick shards for a wall that gets smashed, by a crash or by the shield.
ParticleSystemComponent brickShards(Vector2 at, Sprite shard) {
  return ParticleSystemComponent(
    position: at,
    priority: kPrioBurst,
    particle: Particle.generate(
      count: kShardCount,
      lifespan: kShardLifespan,
      generator: (_) {
        final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * pi;
        final speed = kShardSpeed * (0.5 + _rng.nextDouble() * 0.8);
        final size = kShardSize * (0.5 + _rng.nextDouble() * 0.6);
        return AcceleratedParticle(
          speed: Vector2(cos(angle), sin(angle))..scale(speed),
          acceleration: Vector2(0, kShardGravity),
          child: RotatingParticle(
            to: (_rng.nextDouble() - 0.5) * 4 * pi,
            child: SpriteParticle(sprite: shard, size: Vector2.all(size)),
          ),
        );
      },
    ),
  );
}
