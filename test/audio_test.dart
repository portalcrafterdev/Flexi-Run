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
