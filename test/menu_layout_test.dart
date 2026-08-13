import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/games.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';
import 'package:flexirun/ui/level_picker.dart';
import 'package:flexirun/ui/menu_logo.dart';
import 'package:flexirun/ui/menu_overlay.dart';
import 'package:flexirun/ui/menu_runner.dart';

// The home screen has to fit the phone it is actually held on. A landscape
// handset is wide and short - about 800 by 360 points - and the menu is laid
// out across that rather than stacked down the middle of it, so the thing most
// likely to go wrong is the layout running off an edge.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    // The sign-in button is the whole reason the column got tall enough to
    // slide under the gear, and it renders as nothing on a desktop test host.
    // Without this the layout tests measure a column that is one button
    // shorter than the real one and miss exactly the case they exist for.
    Games.debugSupported = true;
    addTearDown(Games.reset);
    final game = await boot();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MenuOverlay(game: game))),
    );
  }

  group('home screen', () {
    testWidgets('fits a landscape handset without overflowing', (tester) async {
      await pumpAt(tester, const Size(800, 360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a tablet', (tester) async {
      await pumpAt(tester, const Size(1180, 820));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the gear never sits on top of the buttons', (tester) async {
      // The bug this pins: the gear sits in the screen's own corner, outside
      // the menu's layout, while the column of buttons centres itself in the
      // whole screen. Every button added to that column therefore grows it
      // upwards as well as down, and the fourth one - sign in - pushed the
      // Hard tile up underneath the gear.
      //
      // Written as "do these overlap" rather than "is the gear above them", so
      // it keeps holding wherever the gear is moved to next.
      for (final size in <Size>[Size(900, 430), Size(800, 360)]) {
        await pumpAt(tester, size);
        final gear = tester.getRect(find.bySemanticsLabel('Settings'));

        // The whole picker, not the word "Hard": the label is inset inside its
        // tile, so measuring the text passes while the tile it is printed on
        // is still tucked under the gear.
        expect(
          gear.overlaps(tester.getRect(find.byType(LevelPicker))),
          isFalse,
          reason: 'gear on the level picker at $size',
        );
        for (final label in <String>['PLAY', 'HOW TO PLAY']) {
          expect(
            gear.overlaps(tester.getRect(find.text(label))),
            isFalse,
            reason: 'gear on $label at $size',
          );
        }
      }
    });

    testWidgets('spreads across a landscape screen', (tester) async {
      await pumpAt(tester, const Size(800, 360));

      // The name sits in the left half and the buttons in the right, rather
      // than everything sharing one column down the middle.
      final logo = tester.getTopLeft(find.byType(GameLogo));
      final play = tester.getTopLeft(find.text('PLAY'));
      expect(logo.dx, lessThan(400));
      expect(play.dx, greaterThan(400));

      // And the character is on it at all, which is the whole point of the
      // left half being kept clear.
      expect(find.byType(MenuRunner), findsOneWidget);
    });

    testWidgets('falls back to one column when there is no room', (
      tester,
    ) async {
      // Too short for the runner and the buttons at once: everything stacks,
      // and the character steps out rather than being squashed in.
      await pumpAt(tester, const Size(700, 240));
      expect(tester.takeException(), isNull);
      expect(find.byType(MenuRunner), findsNothing);
      expect(find.text('PLAY'), findsOneWidget);
    });
  });
}
