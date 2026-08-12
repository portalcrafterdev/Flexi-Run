import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/game/difficulty.dart';

void main() {
  group('speedFor', () {
    test('starts at the learning speed', () {
      expect(speedFor(0), kSpeedStart);
    });

    // Stated as inequalities rather than against the section 16 literals, so
    // these hold whether the speed is held flat (as it is now) or ramped.
    test('is halfway up the ramp at half the ramp score', () {
      expect(
        speedFor(kRampScore ~/ 2),
        closeTo((kSpeedStart + kSpeedMax) / 2, 0.5),
      );
    });

    test('is at the ceiling by the ramp score and never rises again', () {
      expect(speedFor(kRampScore.toInt()), closeTo(kSpeedMax, 1e-9));
      expect(speedFor(kRampScore.toInt() * 5), kSpeedMax);
      expect(speedFor(100000), kSpeedMax);
    });

    test('never exceeds the ceiling at any score', () {
      // The complaint this guards: a run that keeps getting faster until it is
      // unplayable. Whatever the curve, the top speed is the top speed.
      for (var score = 0; score <= 10000; score += kScorePerWall) {
        expect(speedFor(score), lessThanOrEqualTo(kSpeedMax));
      }
    });

    test('climbs gently enough to stay playable for the first ten walls', () {
      // Ten walls in, a child is still learning the shapes; the game should
      // barely have sped up by then, if at all.
      final climbed = speedFor(10 * kScorePerWall) - kSpeedStart;
      expect(climbed, lessThanOrEqualTo((kSpeedMax - kSpeedStart) / 4));
    });

    test('never decreases as the score climbs', () {
      var previous = speedFor(0);
      for (var score = 0; score <= 1000; score += kScorePerWall) {
        final current = speedFor(score);
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('gapFor', () {
    test('starts at the age six reaction window', () {
      expect(gapFor(0), kGapStart);
    });

    test('is halfway down the ramp at half the ramp score', () {
      expect(gapFor(kRampScore ~/ 2), closeTo((kGapStart + kGapMin) / 2, 1e-9));
    });

    test('clamps to the floor and never drops again', () {
      expect(gapFor(kRampScore.toInt()), closeTo(kGapMin, 1e-9));
      expect(gapFor(kRampScore.toInt() * 5), kGapMin);
    });

    test('never increases as the score climbs', () {
      var previous = gapFor(0);
      for (var score = 0; score <= 1000; score += kScorePerWall) {
        final current = gapFor(score);
        expect(current, lessThanOrEqualTo(previous));
        previous = current;
      }
    });

    test('always leaves more thinking time than a wall takes to cross', () {
      // Otherwise two walls could overlap the player at once.
      for (var score = 0; score <= 1000; score += kScorePerWall) {
        final spacing = speedFor(score) * gapFor(score);
        expect(spacing, greaterThan(kMinWallSeparationZ));
      }
    });
  });
}
