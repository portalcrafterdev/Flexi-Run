import 'dart:math';

import 'constants.dart';

/// Picks from [values] with a bias away from what came up recently, and never
/// returns the same value more than twice in a row.
///
/// Used for both the wall shapes and the lane the hole sits in, so neither
/// settles into a run that a child can beat without looking.
class WeightedPicker<T> {
  WeightedPicker(this.values, {Random? random})
    : assert(values.length > 2, 'need three or more to avoid a forced repeat'),
      _rng = random ?? Random();

  final List<T> values;
  final Random _rng;

  T? _last;
  T? _beforeLast;

  void reset() {
    _last = null;
    _beforeLast = null;
  }

  T next() {
    final weights = <double>[];
    var total = 0.0;
    for (final value in values) {
      var weight = kPickBaseWeight;
      if (value == _last) weight *= kPickRecentBias;
      if (value == _beforeLast) weight *= kPickRecentBias;
      if (value == _last && value == _beforeLast) weight = 0;
      weights.add(weight);
      total += weight;
    }

    var roll = _rng.nextDouble() * total;
    var picked = values.first;
    for (var i = 0; i < values.length; i++) {
      roll -= weights[i];
      if (roll <= 0 && weights[i] > 0) {
        picked = values[i];
        break;
      }
      if (weights[i] > 0) picked = values[i];
    }

    _beforeLast = _last;
    _last = picked;
    return picked;
  }
}
