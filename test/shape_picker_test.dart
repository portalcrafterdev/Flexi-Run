import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/shape_kind.dart';

void main() {
  test('never repeats the same shape more than twice in a row', () {
    final picker = ShapePicker(random: Random(1234));
    var run = 0;
    ShapeKind? previous;

    for (var i = 0; i < 5000; i++) {
      final shape = picker.next();
      run = shape == previous ? run + 1 : 1;
      expect(
        run,
        lessThanOrEqualTo(2),
        reason: 'three ${shape.label}s in a row',
      );
      previous = shape;
    }
  });

  test('still produces every shape', () {
    final picker = ShapePicker(random: Random(7));
    final seen = <ShapeKind>{};
    for (var i = 0; i < 200; i++) {
      seen.add(picker.next());
    }
    expect(seen, ShapeKind.values.toSet());
  });

  test('reset clears the history', () {
    final picker = ShapePicker(random: Random(3))..next();
    picker.reset();
    expect(ShapeKind.values, contains(picker.next()));
  });

  test('shape paths are all inside their half extent', () {
    for (final kind in ShapeKind.values) {
      final bounds = shapePath(kind, const Offset(50, 50), 20).getBounds();
      expect(bounds.width, lessThanOrEqualTo(40.001));
      expect(bounds.height, lessThanOrEqualTo(40.001));
      expect(bounds.center.dx, closeTo(50, 0.5));
    }
  });
}
