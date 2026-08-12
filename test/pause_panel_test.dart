import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/game/shape_shifter_game.dart';
import 'package:flexirun/ui/pause_overlay.dart';
import 'package:flexirun/ui/sound_levels.dart';

// Pausing is when a game gets turned down: it is the moment a parent reaches
// for the phone. These check the bars are actually there and actually wired,
// not just that the panel renders.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  Future<ShapeShifterGame> parkedRun() async {
    final game = await initializeGame(ShapeShifterGame.new);
    game.startRun();
    game.requestPause();
    return game;
  }

  Future<void> show(WidgetTester tester, ShapeShifterGame game) =>
      tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PausePanel(game: game))),
      );

  testWidgets('a parked run offers both levels', (tester) async {
    final game = await parkedRun();
    await show(tester, game);

    expect(find.byType(SoundLevels), findsOneWidget);
    expect(
      find.byType(Slider),
      findsNWidgets(2),
      reason: 'sound and music, both adjustable without leaving the run',
    );
  });

  testWidgets('the panel is only there while the run is parked', (
    tester,
  ) async {
    final game = await initializeGame(ShapeShifterGame.new);
    game.startRun();
    await show(tester, game);

    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('moving a bar mid-pause is remembered', (tester) async {
    final game = await parkedRun();
    await show(tester, game);

    final sliders = find.byType(Slider);
    tester.widget<Slider>(sliders.at(0)).onChanged!(0.4);
    tester.widget<Slider>(sliders.at(1)).onChanged!(0.2);
    await tester.pump();

    expect(Prefs.soundLevel, 0.4);
    expect(Prefs.musicLevel, 0.2);
  });

  testWidgets('the bars show what is already set, not a default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sound_level': 0.6,
      'music_level': 0.0,
    });
    await Prefs.init();

    final game = await parkedRun();
    await show(tester, game);

    final sliders = find.byType(Slider);
    expect(tester.widget<Slider>(sliders.at(0)).value, 0.6);
    expect(tester.widget<Slider>(sliders.at(1)).value, 0.0);
  });

  testWidgets('the run carries on from the panel', (tester) async {
    final game = await parkedRun();
    await show(tester, game);

    await tester.tap(find.text('KEEP GOING'));
    await tester.pump();

    expect(game.pauseNotifier.value, isFalse);
    expect(find.byType(Slider), findsNothing);
  });
}
