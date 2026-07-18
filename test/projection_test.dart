import 'package:flutter_test/flutter_test.dart';
import 'package:morphorun/core/constants.dart';
import 'package:morphorun/game/projection.dart';

void main() {
  group('scaleAt', () {
    test('is life size at the runner\'s own plane', () {
      expect(scaleAt(0), 1.0);
    });

    test('shrinks with distance and never reaches zero', () {
      expect(scaleAt(kWallSpawnZ), lessThan(0.25));
      expect(scaleAt(kWallSpawnZ), greaterThan(0));
    });

    test('grows monotonically as something approaches', () {
      var previous = scaleAt(kWallSpawnZ);
      for (var z = kWallSpawnZ; z >= kMinDrawZ; z -= 50) {
        expect(scaleAt(z), greaterThanOrEqualTo(previous));
        previous = scaleAt(z);
      }
    });

    test('stays finite over everything that is ever drawn', () {
      expect(scaleAt(kMinDrawZ), lessThan(10));
      expect(scaleAt(kMinDrawZ), greaterThan(1));
    });
  });

  group('lane', () {
    test('runs from the near lane to the vanishing point', () {
      expect(laneXAt(0), kNearLaneX);
      expect(laneXAt(100000), closeTo(kVanishX, 1));
    });

    test('ground rises to the horizon with distance', () {
      expect(groundYAt(0), kNearGroundY);
      expect(groundYAt(100000), closeTo(kHorizonY, 1));
      expect(groundYAt(kWallSpawnZ), lessThan(kNearGroundY));
      expect(groundYAt(kWallSpawnZ), greaterThan(kHorizonY));
    });

    test('the verges spread apart as they approach', () {
      final far = sideXAt(kRoadHalfWidth, kWallSpawnZ) -
          sideXAt(-kRoadHalfWidth, kWallSpawnZ);
      final near = sideXAt(kRoadHalfWidth, 0) - sideXAt(-kRoadHalfWidth, 0);
      expect(near, greaterThan(far));
      expect(near, closeTo(kRoadHalfWidth * 2, 0.001));
    });
  });

  group('depthPriority', () {
    test('puts anything ahead of the runner behind it', () {
      for (final z in <double>[kWallSpawnZ, 800, 400, 100, 1]) {
        expect(
          depthPriority(z),
          lessThan(kPrioPlayer),
          reason: 'a wall at z=$z should draw behind the runner',
        );
      }
    });

    test('puts anything past the runner in front of it', () {
      for (final z in <double>[kWallHitZ, -20, -80, kWallCullZ]) {
        expect(
          depthPriority(z),
          greaterThan(kPrioPlayer),
          reason: 'a wall at z=$z should draw in front of the runner',
        );
      }
    });

    test('nearer things draw over further ones', () {
      expect(depthPriority(400), greaterThan(depthPriority(900)));
      expect(depthPriority(-80), greaterThan(depthPriority(-10)));
    });

    test('stays clear of the bursts layer', () {
      expect(depthPriority(kWallCullZ), lessThan(kPrioBurst));
    });
  });
}
