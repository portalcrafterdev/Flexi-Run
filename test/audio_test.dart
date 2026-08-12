import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/audio.dart';
import 'package:flexirun/core/prefs.dart';

// A backgrounded game makes no noise at all.
//
// It used to pause the music and leave the sound effects alone, and a sound
// effect is a platform side player that runs to the end of its clip on its
// own: a coin taken in the last moment before the home button carried on
// chiming over the launcher.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
    Audio.wake();
  });

  tearDown(Audio.wake);

  group('leaving the screen', () {
    test('sound is on to begin with', () {
      expect(Audio.isOffScreen, isFalse);
    });

    test('suspending refuses every new sound', () async {
      await Audio.suspend();
      expect(Audio.isOffScreen, isTrue);

      // None of these may reach the platform while the app is away. They are
      // all fire and forget, so the only thing to assert is that they are
      // refused rather than thrown.
      Audio.coin(3);
      Audio.pass(2);
      Audio.hit();
      Audio.tap();
      Audio.gameOver();
      expect(Audio.isOffScreen, isTrue);
    });

    test('coming back lets sound in again', () async {
      await Audio.suspend();
      Audio.wake();
      expect(Audio.isOffScreen, isFalse);
    });

    test('a dragged music bar settles on its final position', () async {
      // The bug this guards: every step of a drag fired an unserialised round
      // trip to the player, so the stop from passing zero could land after the
      // start from coming back up. The music went off and stayed off, with
      // nothing left that would turn it on again.
      //
      // Fired the way a drag fires them - all at once, none awaited - and then
      // the queue is drained. Whatever the bar was left on has to be what the
      // audio layer ends up believing.
      for (final level in <double>[0.8, 0.4, 0, 0.2, 0, 1.0]) {
        await Prefs.setMusicLevel(level);
        unawaited(Audio.applyMusicLevel());
      }
      // Joining the back of the queue: it cannot finish before the jobs in
      // front of it have.
      await Audio.applyMusicLevel();

      expect(Prefs.musicLevel, 1.0);
      // And the queue is idle rather than wedged behind a failed job.
      await Audio.applyMusicLevel().timeout(const Duration(seconds: 5));
    });

    test('waking is not conditional on the run being unpaused', () async {
      // A player who parks the game, leaves, and comes back still has a pause
      // panel with two volume bars on it. If waking rode along with resuming
      // the music, those bars would be silent until they pressed on.
      await Audio.suspend();
      Audio.wake();
      Audio.preview();
      expect(Audio.isOffScreen, isFalse);
    });
  });
}
