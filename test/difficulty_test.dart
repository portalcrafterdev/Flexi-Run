import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/core/level.dart';
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
    // Stated against each level's own numbers rather than against literals, so
    // these keep holding after a playtest retunes one of them.
    for (final level in Level.values) {
      test('${level.name} starts at its own reaction window', () {
        expect(gapFor(0, level), level.gapStart);
      });

      test('${level.name} is halfway down its ramp at half its ramp score', () {
        expect(
          gapFor(level.rampScore ~/ 2, level),
          closeTo((level.gapStart + level.gapMin) / 2, 1e-9),
        );
      });

      test('${level.name} clamps to its floor and never drops again', () {
        expect(gapFor(level.rampScore.toInt(), level), closeTo(level.gapMin, 1e-9));
        expect(gapFor(level.rampScore.toInt() * 5, level), level.gapMin);
      });

      test('${level.name} never increases as the score climbs', () {
        var previous = gapFor(0, level);
        for (var score = 0; score <= 1000; score += kScorePerWall) {
          final current = gapFor(score, level);
          expect(current, lessThanOrEqualTo(previous));
          previous = current;
        }
      });

      test('${level.name} never stacks two walls on the runner at once', () {
        // The real floor under the hardest level: the gap can only tighten so
        // far before the walls it spaces start arriving on top of each other.
        for (var score = 0; score <= 1000; score += kScorePerWall) {
          expect(
            speedFor(score) * gapFor(score, level),
            greaterThan(kMinWallSeparationZ),
          );
        }
      });
    }

    test('every level is harder than the one below it, all the way down', () {
      for (var score = 0; score <= 1000; score += kScorePerWall) {
        expect(
          gapFor(score, Level.easy),
          greaterThan(gapFor(score, Level.medium)),
          reason: 'easy must give more thinking time than medium at $score',
        );
        expect(
          gapFor(score, Level.medium),
          greaterThan(gapFor(score, Level.hard)),
          reason: 'medium must give more thinking time than hard at $score',
        );
      }
    });
  });

  group('levels', () {
    test('medium is the game as it was tuned before levels existed', () {
      // The promise made when levels were added: nothing already signed off
      // moves. If this fails, the default difficulty has been changed.
      expect(Level.medium.gapStart, kGapStart);
      expect(Level.medium.gapMin, kGapMin);
      expect(Level.medium.rampScore, kRampScore);
      expect(Level.medium.lives, kLives);
      expect(Level.medium.shieldEvery, kShieldEveryPasses);
      expect(Level.medium.forgiveSeconds, kForgiveSeconds);
      expect(Level.medium.centreLaneOnly, isFalse);
    });

    test('the speed is the same on every level', () {
      // A child who has learned the timing on one level should not have to
      // learn it again to move up. Only the spacing changes.
      for (var score = 0; score <= 1000; score += kScorePerWall) {
        expect(speedFor(score), kSpeedStart);
      }
    });

    test('easy is the only one that drops the lane mechanic', () {
      expect(Level.easy.centreLaneOnly, isTrue);
      expect(Level.medium.centreLaneOnly, isFalse);
      expect(Level.hard.centreLaneOnly, isFalse);
    });

    test('easy is more forgiving in every way except lives', () {
      // Lives are the same on all three now. Easy earns its name by giving
      // more time to think, more slack on a late tap and a shield more often -
      // not by handing out extra goes, which only made the hearts at the top
      // of the screen mean a different number on each level.
      expect(Level.easy.lives, Level.medium.lives);
      expect(
        Level.easy.forgiveSeconds,
        greaterThan(Level.medium.forgiveSeconds),
      );
      expect(Level.easy.shieldEvery, lessThan(Level.medium.shieldEvery));
      expect(Level.easy.gapStart, greaterThan(Level.medium.gapStart));
    });

    test('hard is tighter but not meaner', () {
      // Deliberate: it squeezes the reaction window rather than taking lives.
      // A life lost to something a child did not understand is what makes them
      // put the phone down.
      expect(Level.hard.lives, Level.medium.lives);
      expect(
        Level.hard.forgiveSeconds,
        lessThan(Level.medium.forgiveSeconds),
      );
      expect(Level.hard.shieldEvery, greaterThan(Level.medium.shieldEvery));
    });
  });
}
