import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/core/shape_kind.dart';
import 'package:flexirun/game/shape_shifter_game.dart';
import 'package:flexirun/tutorial/flexirun_tutorial.dart';
import 'package:flexirun/tutorial/tutorial_caption.dart';
import 'package:flexirun/tutorial/tutorial_controller.dart';
import 'package:flexirun/tutorial/tutorial_runner.dart';
import 'package:flexirun/tutorial/tutorial_store.dart';
import 'package:flexirun/ui/hud.dart';
import 'package:flexirun/ui/menu_overlay.dart';
import 'package:flexirun/ui/shape_pad.dart';

// The tutorial joined to this game.
//
// Two failures here are worse than having no tutorial at all, and neither
// announces itself: a hold that refuses input leaves a sequence nobody can
// finish, and a hold left set leaves a run in which no wall ever spawns.

const _frame = 1 / 60;
const _screen = Size(1280, 720);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  tearDown(() {
    TutorialController.debugStore = null;
    TutorialController.debugDisabled = false;
  });

  Future<ShapeShifterGame> boot() => initializeGame(ShapeShifterGame.new);

  /// The run as the app builds it: the HUD, the pad and the runner over it.
  Future<void> pumpScreen(
    WidgetTester tester,
    ShapeShifterGame game,
    TutorialLink link, {
    TutorialStore? store,
  }) async {
    // The view rather than setSurfaceSize. setSurfaceSize lays the tree out at
    // the size it is given but leaves MediaQuery reporting the view's own
    // 800x600, and a screen that disagrees with the box everything is measured
    // in is a landscape game being tested in portrait-ish letterbox.
    tester.view
      ..physicalSize = _screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            Hud(game: game, link: link),
            ShapePad(game: game, link: link),
            TutorialRunner(game: game, link: link, store: store),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the sequence', () {
    test('Easy is not taught a control it never needs', () {
      final steps = TutorialLink().stepsFor(Level.easy);
      expect(
        steps.map((step) => step.id),
        isNot(contains(kStepLane)),
        reason: 'Easy opens every wall on the middle track',
      );
      // Still teaches the shapes, which is the half that does apply.
      expect(steps.map((step) => step.id), contains(kStepShape));
    });

    test('Medium and Hard are taught the tracks', () {
      for (final level in <Level>[Level.medium, Level.hard]) {
        expect(
          TutorialLink().stepsFor(level).map((step) => step.id),
          contains(kStepLane),
          reason: '${level.label} opens walls off the middle track',
        );
      }
    });

    test('each level is remembered separately', () {
      // One flag for all three would mean a child who learned on Easy moved up
      // to Medium and was never shown the arrows.
      final flags = Level.values.map(tutorialFlagFor).toSet();
      expect(flags, hasLength(Level.values.length));
    });

    test('reporting with nothing bound is harmless', () {
      // Every control reports unconditionally, which is what keeps the taught
      // path and the ordinary path the same path.
      expect(() => TutorialLink().report(kStepShape), returnsNormally);
    });

    testWidgets('every step points at something that is on screen', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      // No store, so nothing starts: this is about the keys being set, not
      // about the sequence running.
      TutorialController.debugDisabled = true;
      await pumpScreen(tester, game, link);

      for (final step in link.stepsFor(game.level.value)) {
        expect(
          step.targetKey.currentContext,
          isNotNull,
          reason: '${step.id} points at a widget the screen never built',
        );
      }
    });
  });

  /// Everything the app shows at once, so a sequence can be watched handing
  /// over from the home screen to the run.
  Future<void> pumpAll(
    WidgetTester tester,
    ShapeShifterGame game,
    TutorialLink link, {
    TutorialStore? store,
  }) async {
    tester.view
      ..physicalSize = _screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: <Widget>[
            MenuOverlay(game: game, link: link),
            Hud(game: game, link: link),
            ShapePad(game: game, link: link),
            TutorialRunner(game: game, link: link, store: store),
          ],
        ),
      ),
    );
    // Pumped, never settled: the home screen's clouds drift on a repeating
    // animation, so pumpAndSettle waits for a frame that never comes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(seconds: 1));
  }

  List<String> captions(WidgetTester tester) => tester
      .widgetList<TypedText>(find.byType(TypedText))
      .map((widget) => widget.text)
      .toList();

  group('the home screen sequence', () {
    test('ends on the button that starts the game', () {
      // The last thing it asks for is the thing that gets them playing, so the
      // marks hand straight over to the run instead of stopping to be
      // dismissed.
      final steps = TutorialLink().menuSteps();
      expect(steps.last.id, kStepPlay);
      expect(steps.last.advance, TutorialAdvance.target);
    });

    test('only the last step waits for a press', () {
      // A child made to open HOW TO PLAY before being allowed to play has been
      // given a chore, not a lesson.
      final steps = TutorialLink().menuSteps();
      for (final step in steps.take(steps.length - 1)) {
        expect(
          step.advance,
          TutorialAdvance.anywhere,
          reason: '${step.id} makes the player press something to get past it',
        );
      }
    });

    test('is remembered apart from every run sequence', () {
      final flags = Level.values.map(tutorialFlagFor).toSet();
      expect(flags, isNot(contains(kMenuTutorialFlag)));
    });

    testWidgets('comes up on the home screen', (tester) async {
      final game = await boot();
      final link = TutorialLink();
      await pumpAll(tester, game, link, store: MemoryTutorialStore());

      expect(find.text(kSkipLabel), findsOneWidget);
      expect(captions(tester).single, TutorialLink().menuSteps().first.caption);
      // Nothing is held: the menu has nothing coming at anybody.
      expect(game.tutorialHold.value, isFalse);
    });

    testWidgets('the caption lands on screen, not off the bottom edge', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      await pumpAll(tester, game, link, store: MemoryTutorialStore());

      final screen = Rect.fromLTWH(0, 0, _screen.width, _screen.height);
      final caption = tester.getRect(find.byType(TypedText));
      expect(
        screen.contains(caption.topLeft) && screen.contains(caption.bottomRight),
        isTrue,
        reason: 'caption at $caption, screen is $screen',
      );
    });

    testWidgets('the scrim blocks the screen around the hole', (tester) async {
      // Four blockers, or the mark explains one thing while every other
      // control on the screen stays live underneath it.
      final game = await boot();
      final link = TutorialLink();
      await pumpAll(tester, game, link, store: MemoryTutorialStore());

      final hole = tester.getRect(find.byKey(link.levels));
      // A tap well away from the hole must be refused, not land on the menu.
      await tester.tapAt(Offset(hole.left / 2, _screen.height - 20));
      await tester.pump();

      expect(
        game.state,
        GameState.menu,
        reason: 'a tap outside the hole got through to the screen below',
      );
    });

    testWidgets('gives way to the run sequence when a run starts', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      await pumpAll(tester, game, link, store: MemoryTutorialStore());
      expect(captions(tester).single, TutorialLink().menuSteps().first.caption);

      game.startRun();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(seconds: 1));

      expect(
        captions(tester).single,
        TutorialLink().stepsFor(game.level.value).first.caption,
        reason: 'the home screen marks were still up during the run',
      );
      expect(game.tutorialHold.value, isTrue);
    });

    testWidgets('a target that never arrives does not loop forever', (
      tester,
    ) async {
      // No MenuOverlay in this tree, so none of the keys the home sequence
      // points at are ever laid out. The overlay looks again every frame while
      // it waits; without a budget that is a rebuild loop for as long as the
      // app is open, showing nothing and reporting nothing.
      final game = await boot();
      final link = TutorialLink();
      final store = MemoryTutorialStore();
      tester.view
        ..physicalSize = _screen
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialRunner(game: game, link: link, store: store),
        ),
      );
      // Settles rather than timing out, which is the whole point.
      await tester.pumpAndSettle();

      expect(find.text(kSkipLabel), findsNothing);
      expect(
        await store.hasSeen(kMenuTutorialFlag),
        isFalse,
        reason: 'a late target burned the lesson for every future launch',
      );
    });
  });

  group('the hole round the stats', () {
    testWidgets('holds no empty space when no coins have been taken', (
      tester,
    ) async {
      // A run starts on zero coins. The counter used to fade out with
      // AnimatedOpacity, which kept it laid out at full width - so the group
      // the mark cuts around carried a coin's worth of nothing on its right,
      // and the hole looked like a bug.
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      TutorialController.debugDisabled = true;
      await pumpScreen(tester, game, link);

      final empty = tester.getRect(find.byKey(link.stats)).width;

      game.coins.value = 7;
      await tester.pumpAndSettle();
      final withCoins = tester.getRect(find.byKey(link.stats)).width;

      expect(
        withCoins,
        greaterThan(empty + 20),
        reason: 'the counter took the same room whether or not it was shown',
      );
    });
  });

  group('the hold', () {
    test('stops walls arriving', () async {
      final game = await boot();
      game.startRun();
      game.holdForTutorial();

      for (var i = 0; i < 600; i++) {
        game.update(_frame);
      }
      expect(
        game.walls,
        isEmpty,
        reason: 'ten seconds held and something still came at the player',
      );
      expect(game.lives.value, game.level.value.lives);
    });

    test('leaves the controls live', () async {
      // The whole difference from a pause. The player is being ASKED to press
      // something, so a hold that refused input would be a sequence that could
      // never be finished.
      final game = await boot();
      game.startRun();
      game.holdForTutorial();

      final other = ShapeKind.values.firstWhere(
        (kind) => kind != game.activeShape.value,
      );
      game.morph(other);
      expect(game.activeShape.value, other);

      final lane = game.activeLane.value;
      game.stepLane(1);
      expect(game.activeLane.value, isNot(lane));
    });

    test('a wall arrives again once it is released', () async {
      final game = await boot();
      game.startRun();
      game.holdForTutorial();
      for (var i = 0; i < 120; i++) {
        game.update(_frame);
      }
      game.releaseFromTutorial();

      var frames = 0;
      while (game.walls.isEmpty && frames < 1200) {
        game.update(_frame);
        frames++;
      }
      expect(game.walls, isNotEmpty, reason: 'the run never resumed');
    });

    test('is refused outside a run', () async {
      final game = await boot();
      // Nothing to hold on the menu, and one set here would be released by
      // nobody, because no run is coming to clear it.
      game.holdForTutorial();
      expect(game.tutorialHold.value, isFalse);
    });

    test('a fresh run clears one left behind', () async {
      final game = await boot();
      game.startRun();
      game.holdForTutorial();
      expect(game.tutorialHold.value, isTrue);

      game.startRun();
      expect(game.tutorialHold.value, isFalse);
    });
  });

  group('the runner', () {
    testWidgets('holds the run while the marks are up', (tester) async {
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      await pumpScreen(tester, game, link, store: MemoryTutorialStore());

      expect(find.text(kSkipLabel), findsOneWidget);
      expect(game.tutorialHold.value, isTrue);
    });

    testWidgets('releases the run when the marks finish', (tester) async {
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      await pumpScreen(tester, game, link, store: MemoryTutorialStore());

      await tester.tap(find.text(kSkipLabel));
      await tester.pumpAndSettle();

      expect(find.text(kSkipLabel), findsNothing);
      expect(
        game.tutorialHold.value,
        isFalse,
        reason: 'the run stayed held after the marks went away',
      );
    });

    testWidgets('releases the run when the sequence is already seen', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      final seen = MemoryTutorialStore(<String>{
        tutorialFlagFor(game.level.value),
      });
      game.startRun();
      await pumpScreen(tester, game, link, store: seen);

      // The hold is taken BEFORE the flag is read - a wall arriving inside that
      // round trip would be one the player was never shown how to pass - so
      // this is the path where it has to be handed back.
      expect(find.text(kSkipLabel), findsNothing);
      expect(game.tutorialHold.value, isFalse);
    });

    testWidgets('going back to the menu takes the marks with it', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      await pumpScreen(tester, game, link, store: MemoryTutorialStore());
      expect(find.text(kSkipLabel), findsOneWidget);

      game.goToMenu();
      await tester.pumpAndSettle();

      expect(find.text(kSkipLabel), findsNothing);
      expect(game.tutorialHold.value, isFalse);
    });

    testWidgets('the real shape button is what advances the sequence', (
      tester,
    ) async {
      final game = await boot();
      final link = TutorialLink();
      game.startRun();
      await pumpScreen(tester, game, link, store: MemoryTutorialStore());

      // Past the stats mark, which any tap clears.
      await tester.tapAt(_screen.center(Offset.zero));
      await tester.pumpAndSettle();

      final before = game.activeShape.value;
      final shapes = game.level.value.shapes;
      // A shape that is not the one already worn, or the morph would be a
      // no-op and this would pass whether the tap landed or not.
      final target = shapes.firstWhere((kind) => kind != before);
      final row = tester.getRect(find.byKey(link.shapeRow));
      final slot = row.width / shapes.length;
      await tester.tapAt(
        Offset(row.left + slot * (shapes.indexOf(target) + 0.5), row.center.dy),
      );
      await tester.pumpAndSettle();

      expect(
        game.activeShape.value,
        target,
        reason: 'the tap never reached the real button through the hole',
      );
    });
  });
}
