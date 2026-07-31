import 'dart:math';

import 'package:flame/components.dart';

import '../core/constants.dart';

/// Decaying camera shake.
///
/// Two different frequencies on the two axes keep it from reading as a single
/// diagonal wobble.
class ScreenShake {
  ScreenShake(Vector2 home) : _home = home.clone();

  final Vector2 _home;
  double _amount = 0;
  double _elapsed = 0;

  bool get isShaking => _amount > 0;

  /// A bigger shake always wins; a smaller one never cuts one short.
  void add(double amount) => _amount = max(_amount, amount);

  void reset() => _amount = 0;

  /// Writes this frame's camera position into [position].
  void apply(double dt, Vector2 position) {
    if (_amount <= 0) return;
    _elapsed += dt;
    _amount = max(0, _amount - kShakeDecay * dt);
    if (_amount == 0) {
      position.setFrom(_home);
      return;
    }
    position.setValues(
      _home.x + sin(_elapsed * 2 * pi * kShakeHzX) * _amount,
      _home.y + cos(_elapsed * 2 * pi * kShakeHzY) * _amount,
    );
  }
}
