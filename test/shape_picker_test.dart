import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/shape_kind.dart';

void main() {
  test('never repeats the same shape more than twice in a row', () {
    final picker = ShapePicker(ShapeKind.values, random: Random(1234));
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
    final picker = ShapePicker(ShapeKind.values, random: Random(7));
    final seen = <ShapeKind>{};
    for (var i = 0; i < 200; i++) {
      seen.add(picker.next());
    }
    expect(seen, ShapeKind.values.toSet());
  });

  test('reset clears the history', () {
    final picker = ShapePicker(ShapeKind.values, random: Random(3))..next();
    picker.reset();
    expect(ShapeKind.values, contains(picker.next()));
  });

  test('only sends down shapes the level has a button for', () {
    // The failure this pins is silent and unwinnable: a triangle arriving on
    // Easy, where the pad has three buttons and none of them is a triangle.
    // The child cannot answer it and loses a life to a wall they never had a
    // way to solve.
    for (final level in Level.values) {
      final picker = ShapePicker(level.shapes, random: Random(11));
      for (var i = 0; i < 400; i++) {
        expect(
          level.shapes,
          contains(picker.next()),
          reason: '${level.name} has no button for it',
        );
      }
    }
  });

  test('the triangle is Hard alone', () {
    expect(Level.hard.shapes, hasLength(ShapeKind.values.length));
    expect(Level.easy.shapes, hasLength(ShapeKind.values.length - 1));
    expect(Level.medium.shapes, hasLength(ShapeKind.values.length - 1));
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
