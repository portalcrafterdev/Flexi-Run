import 'dart:math';

import 'package:flame/components.dart';

import '../core/constants.dart';
import '../core/lane.dart';
import '../core/placeholder_art.dart';
import '../core/shape_kind.dart';

/// The runner, seen from behind as it heads up the path.
///
/// It never moves: it sits at the near end of the lane and the world comes to
/// it. Everything that looks like movement is the sprite being offset and
/// scaled inside this component.
class Player extends PositionComponent with HasVisibility {
  Player(ArtPack art)
    : _art = art,
      // Anchored on its base, so squash and pop happen about the feet
      // instead of lifting the runner off the ground.
      _body = SpriteComponent(
        sprite: art.slime(kStartShape),
        size: Vector2.all(kPlayerBodySize),
        anchor: Anchor.bottomCenter,
        position: Vector2(kPlayerHalf, kPlayerBodySize),
      ),
      _ring = SpriteComponent(
        sprite: art.shieldRing,
        size: Vector2.all(kPlayerBodySize * kShieldRingScale),
        anchor: Anchor.center,
        position: Vector2(kPlayerHalf, kPlayerHalf),
      ),
      // Belongs to the ground, not the body: it stays put and shrinks as the
      // runner bobs up, which is what a real shadow does.
      _shadow = SpriteComponent(
        sprite: art.contactShadow,
        size: Vector2(
          kPlayerBodySize,
          kPlayerBodySize * kContactShadowHeight * 2,
        ),
        anchor: Anchor.center,
        position: Vector2(kPlayerHalf, kPlayerBodySize + kLegLength),
      ),
      _legs = <SpriteComponent>[
        for (var i = 0; i < 2; i++)
          SpriteComponent(
            sprite: art.leg,
            size: Vector2(kLegW, kLegLength),
            anchor: Anchor.topCenter,
          ),
      ],
      _arms = <SpriteComponent>[
        for (var i = 0; i < 2; i++)
          SpriteComponent(
            sprite: art.arm,
            size: Vector2(kArmW, kArmH),
            anchor: Anchor.centerLeft,
            // The left arm is the same sprite mirrored.
            scale: Vector2(i == 0 ? -1 : 1, 1),
          ),
      ],
      super(
        position: Vector2(kNearLaneX, kNearGroundY),
        size: Vector2(kPlayerBodySize, kPlayerBodySize + kLegLength),
        anchor: Anchor.bottomCenter,
        priority: kPrioPlayer,
      );

  final ArtPack _art;
  final SpriteComponent _body;
  final SpriteComponent _ring;
  final SpriteComponent _shadow;
  final List<SpriteComponent> _legs;
  final List<SpriteComponent> _arms;

  ShapeKind shape = kStartShape;

  /// Which track the runner is standing in. Changes the instant the player
  /// asks; [_shiftFrom] only governs how the slide across looks.
  Lane lane = kStartLane;
  bool hasShield = false;

  /// Where the runner looks like it is standing, sliding toward [lane].
  double _visualOffset = kStartLane.offset;

  double _idleT = 0;
  double _popT = 0;
  double _squeezeT = 0;
  double _invulnT = 0;
  double _recoilT = 0;
  double _shieldPulseT = 0;
  double _tuckT = 0;

  bool get isInvulnerable => _invulnT > 0;

  /// Where the ground is, in this component's own coordinates.
  static const groundY = kPlayerBodySize + kLegLength;

  /// The lowest point any foot reaches this frame.
  ///
  /// It should be exactly [groundY] at every moment of the run: one foot is
  /// always planted. If this ever lifts, the runner is floating.
  double get lowestFootY =>
      _legs.map((leg) => leg.position.y + leg.size.y).reduce(max);

  /// How high the body is riding, in this component's own coordinates.
  double get bodyY => _body.position.y;

  @override
  Future<void> onLoad() async {
    _ring.opacity = 0;
    // Shadow first of all, then limbs behind the body so they read as
    // attached to it.
    await addAll(<Component>[_shadow, _ring, ..._legs, ..._arms, _body]);
  }

  /// Instant on tap. The pop that follows is cosmetic and gates nothing.
  void morph(ShapeKind kind) {
    if (kind == shape) return;
    shape = kind;
    _body.sprite = _art.slime(kind);
    _popT = kPopSeconds;
  }

  /// Steps sideways. Instant as far as the rules are concerned; the slide
  /// across is only how it looks.
  void moveTo(Lane target) => lane = target;

  /// Going through a hole: squash on the way in, and pull the limbs in behind
  /// the body so nothing is left outside the opening to be cut off by brick.
  void squeeze() {
    _squeezeT = kSqueezeSeconds;
    _tuckT = kTuckSeconds;
  }

  bool get isTucking => _tuckT > 0;

  /// Rises fast, holds through the crossing, releases gently.
  double get _tuck {
    if (_tuckT <= 0) return 0;
    final elapsed = kTuckSeconds - _tuckT;
    if (elapsed < kTuckRiseSeconds) return elapsed / kTuckRiseSeconds;
    if (_tuckT < kTuckFallSeconds) return _tuckT / kTuckFallSeconds;
    return 1;
  }

  void setInvulnerable(double seconds) => _invulnT = seconds;

  void hitReact() => _recoilT = kRecoilSeconds;

  void grantShield() {
    hasShield = true;
    _shieldPulseT = kShieldRingPulseSeconds;
    _body.tint(kShieldColor.withValues(alpha: kShieldTintOpacity));
  }

  void consumeShield() {
    hasShield = false;
    _shieldPulseT = 0;
    _body.paint.colorFilter = null;
  }

  void reset() {
    shape = kStartShape;
    lane = kStartLane;
    _visualOffset = kStartLane.offset;
    position.x = kNearLaneX + _visualOffset;
    _body.sprite = _art.slime(shape);
    consumeShield();
    _idleT = 0;
    _popT = 0;
    _squeezeT = 0;
    _invulnT = 0;
    _recoilT = 0;
    _tuckT = 0;
    _body.opacity = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _idleT += dt;
    _popT = max(0, _popT - dt);
    _squeezeT = max(0, _squeezeT - dt);
    _invulnT = max(0, _invulnT - dt);
    _recoilT = max(0, _recoilT - dt);
    _shieldPulseT = max(0, _shieldPulseT - dt);
    _tuckT = max(0, _tuckT - dt);
    _slide(dt);

    // One run cycle, two steps. `stride` is where the legs are in it and
    // `spread` is how far apart they are: 1 as a foot lands, 0 as they pass
    // under the body.
    final cycle = _idleT * 2 * pi * kRunHz;
    final stride = sin(cycle);
    final spread = stride.abs();

    // Weight going down into the landing and back up out of it. Squash on the
    // way down, stretch on the way up, both off the same number.
    final weight = (spread - 0.5) * 2;
    var sx = 1 + kRunSquash * weight;
    var sy = 1 - kRunSquash * weight;

    if (_popT > 0) {
      final pop = 1 + (kPopScale - 1) * sin((1 - _popT / kPopSeconds) * pi);
      sx *= pop;
      sy *= pop;
    }
    if (_squeezeT > 0) {
      final e = sin((1 - _squeezeT / kSqueezeSeconds) * pi);
      sx *= 1 + (kSqueezeX - 1) * e;
      sy *= 1 + (kSqueezeY - 1) * e;
    }

    // A crash knocks the runner back toward the camera.
    final recoilY = _recoilT > 0
        ? kRecoilPixels * (_recoilT / kRecoilSeconds)
        : 0.0;
    // Lowest as a foot lands, highest as the legs pass under the body.
    final bobY = (spread - 0.5) * kRunBobPixels + recoilY;
    final swayX = stride * kRunSwayPixels;
    final opacity = _invulnT > 0 && (_invulnT * kBlinkHz).floor().isEven
        ? kBlinkDimOpacity
        : 1.0;

    _body.position.setValues(kPlayerHalf + swayX, kPlayerBodySize + bobY);
    _body.scale.setValues(sx, sy);
    _body.opacity = opacity;

    _updateLimbs(stride, bobY, swayX, opacity);
    _updateRing(bobY, swayX);
    _updateShadow(bobY);
  }

  /// The shadow tightens and darkens as the runner comes down, and spreads and
  /// fades as it rises. A shadow that never changes reads as a painted-on
  /// smudge; this is what sells the contact.
  void _updateShadow(double bobY) {
    final lift = (-bobY / kRunBobPixels).clamp(-1.0, 1.0);
    final scale = 1 - lift * kShadowLiftScale;
    _shadow
      ..scale.setValues(scale, scale)
      ..opacity = (1 - lift * kShadowLiftFade).clamp(0.0, 1.0);
  }

  /// Eases the runner across to whichever lane it now belongs in.
  ///
  /// Constant speed rather than a tween from a fixed start, so a second nudge
  /// part way across picks up from where the runner actually is.
  void _slide(double dt) {
    final target = lane.offset;
    final step = kLaneOffset / kLaneShiftSeconds * dt;
    if ((target - _visualOffset).abs() <= step) {
      _visualOffset = target;
    } else {
      _visualOffset += target > _visualOffset ? step : -step;
    }
    position.x = kNearLaneX + _visualOffset;
  }

  /// Legs and arms, both phase locked to the same stride.
  ///
  /// The legs are the part that matters. A leg that is swinging keeps its
  /// length and lifts its foot clear; a leg that is planted is stretched from
  /// the hip down to the ground, so its foot stays exactly on the floor while
  /// the body rides up and down over it. That is the difference between a
  /// runner and a sprite being waved about above a road.
  void _updateLimbs(
    double stride,
    double bobY,
    double swayX,
    double opacity,
  ) {
    final tuck = _tuck;
    // Drawing the limbs up into the body, which is the same shape as the hole
    // and so always fits through it.
    final hipY = kPlayerBodySize + bobY - tuck * kLegTuckRise;
    final spreadScale = 1 - tuck * (1 - kLegTuckSpread);

    for (var i = 0; i < _legs.length; i++) {
      final phase = i == 0 ? stride : -stride;
      final swinging = phase > 0;
      final planted = max(kLegMinLength, groundY - hipY);
      _legs[i]
        ..position.setValues(
          kPlayerHalf +
              swayX +
              ((i == 0 ? -kLegSpread : kLegSpread) + phase * kLegSwing) *
                  spreadScale,
          swinging ? hipY - phase * kLegLift : hipY,
        )
        ..size.setValues(
          kLegW,
          (swinging ? kLegLength : planted) * (1 - tuck) +
              kLegMinLength * tuck,
        )
        ..opacity = opacity;
    }

    for (var i = 0; i < _arms.length; i++) {
      // Arms lead the opposite leg, and swing from the shoulder rather than
      // sliding up and down beside it.
      final phase = i == 0 ? -stride : stride;
      final outward = i == 0 ? -1.0 : 1.0;
      final reach = kPlayerHalf - kArmOverlap - tuck * kArmTuckIn;
      _arms[i]
        ..position.setValues(
          kPlayerHalf + swayX + outward * reach,
          kPlayerBodySize * 0.62 + bobY + phase * kArmLift,
        )
        ..angle = phase * kArmSwing * outward
        ..scale.setValues(outward * (1 - tuck * kArmTuckScale), 1)
        ..opacity = opacity;
    }
  }

  void _updateRing(double bobY, double swayX) {
    if (!hasShield) {
      _ring.opacity = 0;
      return;
    }
    _ring
      ..opacity = kShieldIdleOpacity
      ..position.setValues(kPlayerHalf + swayX, kPlayerHalf + bobY);
    final pulse = _shieldPulseT > 0
        ? 1 +
              (kShieldRingPulseScale - 1) *
                  sin((1 - _shieldPulseT / kShieldRingPulseSeconds) * pi)
        : 1.0;
    _ring.scale.setValues(pulse, pulse);
  }
}
