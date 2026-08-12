import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';
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
