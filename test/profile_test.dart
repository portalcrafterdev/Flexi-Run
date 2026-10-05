import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';

// Whose progress is whose.
//
// Written against a real complaint: a score set while signed in was still on
// the menu after signing out, because every score lived under one key with no
// account attached. The worse half of the same bug is that the next person to
// sign in on that phone inherited it as their own.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  test('the game opens on the signed-out profile', () {
    expect(Prefs.profile, Prefs.guest);
  });

  test('a signed-in score does not follow the player out', () async {
    // The reported bug, exactly.
    Prefs.useProfile(Prefs.profileFor('player-a'));
    await Prefs.setHighScore(Level.easy, 20);
    expect(Prefs.highScore(Level.easy), 20);

    Prefs.useProfile(Prefs.guest);

    expect(
      Prefs.highScore(Level.easy),
      0,
      reason: "the account's score was still on screen signed out",
    );
  });

  test('and is waiting when they come back', () async {
    // Separate, not deleted. Signing out must not cost anybody a thing.
    final account = Prefs.profileFor('player-a');
    Prefs.useProfile(account);
    await Prefs.setHighScore(Level.easy, 20);
    await Prefs.addLifetimeCoins(14);
    await Prefs.addAwardsWon(<String>{'first_run'});

    Prefs.useProfile(Prefs.guest);
    Prefs.useProfile(account);

    expect(Prefs.highScore(Level.easy), 20);
    expect(Prefs.lifetimeCoins, 14);
    expect(Prefs.awardsWon, contains('first_run'));
  });

  test('two people on one phone do not inherit each other', () async {
    Prefs.useProfile(Prefs.profileFor('player-a'));
    await Prefs.setHighScore(Level.hard, 300);
    await Prefs.addLifetimeCoins(99);

    Prefs.useProfile(Prefs.profileFor('player-b'));

    expect(Prefs.highScore(Level.hard), 0);
    expect(Prefs.lifetimeCoins, 0);
    expect(Prefs.awardsWon, isEmpty);
  });

  test('settings belong to the phone, not the player', () async {
    // Volume is not progress. Carrying it between accounts is right; carrying
    // a score is not.
    await Prefs.setSoundLevel(0.25);
    await Prefs.setLevel(Level.hard);

    Prefs.useProfile(Prefs.profileFor('player-a'));

    expect(Prefs.soundLevel, 0.25);
    expect(Prefs.level, Level.hard);
  });

  group('clearing progress', () {
    test('empties the profile that is playing', () async {
      Prefs.useProfile(Prefs.profileFor('player-a'));
      await Prefs.setHighScore(Level.easy, 40);
      await Prefs.addLifetimeCoins(12);
      await Prefs.addAwardsWon(<String>{'first_run'});

      await Prefs.clearProgress();

      expect(Prefs.highScore(Level.easy), 0);
      expect(Prefs.lifetimeCoins, 0);
      expect(Prefs.awardsWon, isEmpty);
    });

    test('leaves the other profile alone', () async {
      Prefs.useProfile(Prefs.guest);
      await Prefs.setHighScore(Level.easy, 70);

      Prefs.useProfile(Prefs.profileFor('player-a'));
      await Prefs.setHighScore(Level.easy, 40);
      await Prefs.clearProgress();

      Prefs.useProfile(Prefs.guest);
      expect(Prefs.highScore(Level.easy), 70);
    });

    test('leaves the settings alone', () async {
      // "Clear my progress" does not mean "and turn the music back up".
      await Prefs.setSoundLevel(0.3);
      await Prefs.setMusicLevel(0.1);
      await Prefs.setHighScore(Level.easy, 40);

      await Prefs.clearProgress();

      expect(Prefs.soundLevel, 0.3);
      expect(Prefs.musicLevel, 0.1);
    });
  });

  group('progress from before profiles existed', () {
    test('is kept, under the signed-out profile', () async {
      // An update must not look like it deleted somebody's record.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'high_score_easy': 120,
        'lifetime_coins': 45,
        'awards_won': <String>['first_run'],
      });
      await Prefs.init();

      expect(Prefs.profile, Prefs.guest);
      expect(Prefs.highScore(Level.easy), 120);
      expect(Prefs.lifetimeCoins, 45);
      expect(Prefs.awardsWon, contains('first_run'));
    });

    test('is only moved once', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'high_score_easy': 120,
      });
      await Prefs.init();
      await Prefs.setHighScore(Level.easy, 400);

      // A second launch must not drag the old value back over the new one.
      await Prefs.init();

      expect(Prefs.highScore(Level.easy), 400);
    });
  });

  screenCase();
}

// The reported bug was not actually in storage - it was on screen. The level
// tiles read storage directly, so when the account behind storage changed they
// kept showing the last player's numbers until the app was restarted.
void screenCase() {
  testWidgets('the menu shows the new player\'s bests, not the last one\'s', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
    final game = await initializeGame(ShapeShifterGame.new);

    Prefs.useProfile(Prefs.profileFor('player-a'));
    await Prefs.setHighScore(Level.easy, 40);
    game.chooseLevel(Level.easy);
    game.refreshProgress();
    expect(game.highScore.value, 40);

    // Signing out swaps the profile underneath.
    Prefs.useProfile(Prefs.guest);
    game.refreshProgress();

    expect(
      game.highScore.value,
      0,
      reason: "the account's best was still on screen signed out",
    );
  });
}
