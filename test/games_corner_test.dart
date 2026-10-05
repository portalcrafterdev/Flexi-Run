import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/games.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/ui/games_corner.dart';

// The round buttons in the menu's top corner, and what Disconnect does.
//
// It is not a platform sign-out - Play Games Services v2 removed that API, so
// nothing a game can call ends the session Google holds. It is a disconnect
// from THIS GAME, and what matters is that it sticks: the platform still
// reports the session, so a disconnect that is not remembered would quietly
// undo itself on the next launch.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  tearDown(() {
    Games.debugSupported = null;
    Games.playerName.value = null;
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));

  testWidgets('is absent while signed out', (tester) async {
    // Nothing to disconnect, and the corner must not change width when
    // somebody signs in mid-session.
    Games.debugSupported = true;
    Games.playerName.value = null;

    await pump(tester, const DisconnectButton());
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('is absent where there is no games account at all', (
    tester,
  ) async {
    Games.debugSupported = false;
    Games.playerName.value = 'Sam';

    await pump(tester, const DisconnectButton());
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('appears once signed in', (tester) async {
    Games.debugSupported = true;
    Games.playerName.value = 'Sam';

    await pump(tester, const DisconnectButton());
    expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
  });

  testWidgets('forgets the player when pressed', (tester) async {
    Games.debugSupported = true;
    Games.playerName.value = 'Sam';

    await pump(tester, const DisconnectButton());
    await tester.tap(find.byIcon(Icons.link_off_rounded));
    await tester.pumpAndSettle();

    expect(Games.playerName.value, isNull);
    expect(Games.isSignedIn, isFalse);
    // And takes itself off screen with the rest of the corner.
    expect(find.byIcon(Icons.link_off_rounded), findsNothing);
  });

  testWidgets('remembers the choice, so it is not undone next launch', (
    tester,
  ) async {
    // The platform session outlives the choice. Without this the player stream
    // would hand the name straight back and the disconnect would look broken.
    Games.debugSupported = true;
    Games.playerName.value = 'Sam';

    await pump(tester, const DisconnectButton());
    await tester.tap(find.byIcon(Icons.link_off_rounded));
    await tester.pumpAndSettle();

    expect(Prefs.gamesOptedOut, isTrue);

    // And init refuses to start listening again while that stands.
    await Games.init();
    expect(Games.playerName.value, isNull);
  });

  testWidgets('its neighbours follow the same rule', (tester) async {
    Games.debugSupported = true;
    Games.playerName.value = null;

    await pump(tester, const AchievementsButton());
    expect(find.byType(Icon), findsNothing);

    Games.playerName.value = 'Sam';
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });
}
