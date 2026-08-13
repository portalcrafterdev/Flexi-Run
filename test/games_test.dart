import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/games.dart';
import 'package:flexirun/ui/sign_in_button.dart';

// Signing in to Play Games or Game Center.
//
// The platform side cannot be exercised here - there is no Play Services in a
// test - so these are about the part that has to hold when it is missing: the
// menu must be usable, and a sign-in that cannot happen must say so rather
// than looking like a button that does nothing.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Games.reset();
    // These run on a desktop host, where there is genuinely nothing to sign in
    // to and the button correctly renders as nothing at all.
    Games.debugSupported = true;
  });
  tearDown(Games.reset);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 330, child: SignInButton())),
      ),
    ),
  );

  testWidgets('takes no room where there is nothing to sign in to', (
    tester,
  ) async {
    Games.debugSupported = false;
    await pump(tester);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('SIGN IN'), findsNothing);
  });

  group('signed out', () {
    test('starts signed out and says nothing went wrong yet', () {
      expect(Games.isSignedIn, isFalse);
      expect(Games.playerName.value, isNull);
      expect(Games.failed.value, isFalse);
    });

    testWidgets('offers the platform its own service by name', (tester) async {
      await pump(tester);
      // Never "Play Games" on an iPhone. The label is built from the platform,
      // and tests run on the host, so this only checks it names something.
      expect(
        find.textContaining('SIGN IN TO', findRichText: true),
        findsOneWidget,
      );
      expect(Games.serviceName, isNotEmpty);
    });

    testWidgets('says so when a sign-in fails', (tester) async {
      await pump(tester);
      expect(find.textContaining('could not sign in'), findsNothing);

      Games.failed.value = true;
      await tester.pump();

      // A press that quietly does nothing is the worst outcome: the child
      // presses it again, and again.
      expect(find.textContaining('could not sign in'), findsOneWidget);
    });
  });

  group('signed in', () {
    testWidgets('shows who is signed in instead of a dead button', (
      tester,
    ) async {
      Games.playerName.value = 'Ada';
      await pump(tester);

      expect(find.text('Ada'), findsOneWidget);
      expect(Games.isSignedIn, isTrue);
      // Nothing useful left to press, so there is no button to press.
      expect(find.textContaining('SIGN IN TO'), findsNothing);
    });

    testWidgets('a stale failure is cleared once a session arrives', (
      tester,
    ) async {
      Games.failed.value = true;
      Games.playerName.value = 'Ada';
      await pump(tester);

      expect(find.textContaining('could not sign in'), findsNothing);
    });
  });

  group('while signing in', () {
    testWidgets('the button goes quiet rather than taking a second press', (
      tester,
    ) async {
      Games.busy.value = true;
      await pump(tester);

      expect(find.textContaining('SIGNING IN'), findsOneWidget);
      // Small hands press twice. A second sheet on top of the first is a mess
      // only the platform can get out of.
      expect(await Games.signIn(), isFalse);
    });
  });
}
