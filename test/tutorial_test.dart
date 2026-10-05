import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/tutorial/tutorial_caption.dart';
import 'package:flexirun/tutorial/tutorial_controller.dart';
import 'package:flexirun/tutorial/tutorial_overlay.dart';
import 'package:flexirun/tutorial/tutorial_store.dart';

// The coach-mark sequence. Every test here is written against a bug that the
// obvious implementation has, and that no amount of looking at the diff finds.

void main() {
  // A real phone, not the 800x600 default: at the default a drag can miss its
  // target entirely and a test whose gesture could never have worked passes
  // for the wrong reason.
  const phone = Size(400, 800);

  setUp(() {
    TutorialController.debugStore = MemoryTutorialStore();
    TutorialController.debugDisabled = false;
  });

  /// A screen with one real button near the top and a slider under it, so a
  /// test can check both that the button still works and that the slider
  /// under the scrim does not.
  Widget host({
    required GlobalKey target,
    required TutorialController tutorial,
    required VoidCallback onPressed,
    ValueChanged<double>? onSlide,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!tutorial.isRunning) tutorial.start(context);
            });
            return Column(
              children: <Widget>[
                const SizedBox(height: 80),
                SizedBox(
                  key: target,
                  width: 160,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      onPressed();
                      tutorial.report('press');
                    },
                    child: const Text('REAL'),
                  ),
                ),
                const SizedBox(height: 120),
                SizedBox(
                  width: 300,
                  child: Slider(
                    value: 0.5,
                    onChanged: onSlide ?? (_) {},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget app) async {
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump();
  }

  TutorialController build(GlobalKey key, {TutorialAdvance? advance}) =>
      TutorialController(
        flag: 'test.v1',
        everyTime: true,
        steps: <TutorialStep>[
          TutorialStep(
            id: 'press',
            targetKey: key,
            caption: 'Tap the real button to carry on.',
            advance: advance ?? TutorialAdvance.target,
          ),
          TutorialStep(
            id: 'second',
            targetKey: key,
            caption: 'And here is the second lesson.',
          ),
        ],
      );

  group('the hole is genuinely empty', () {
    testWidgets('the real handler runs and the step advances', (tester) async {
      // Catches the tutorial proxying the press: if the overlay synthesised
      // the tap, the real onPressed would never fire.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);
      var pressed = 0;

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () => pressed++),
      );
      expect(tutorial.current?.id, 'press');

      await tester.tap(find.text('REAL'));
      await tester.pump();

      expect(pressed, 1, reason: 'the real handler did not run');
      expect(tutorial.current?.id, 'second', reason: 'the step did not advance');
    });

    testWidgets('a timed drag under the scrim does nothing', (tester) async {
      // Catches translucent blockers. With translucent, a tap is absorbed but
      // a DRAG still reaches the widget underneath - so this passes with a tap
      // and only fails with a drag.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);
      var slid = 0;

      await pumpAt(
        tester,
        host(
          target: key,
          tutorial: tutorial,
          onPressed: () {},
          onSlide: (_) => slid++,
        ),
      );

      await tester.timedDrag(
        find.byType(Slider),
        const Offset(60, 0),
        const Duration(milliseconds: 300),
        // Missing is the point: the blocker is meant to take this pointer, so
        // the framework's "that would not hit test" warning is the pass, not a
        // problem. The control-half test below is what proves the drag works
        // at all.
        warnIfMissed: false,
      );
      await tester.pump();

      expect(slid, 0, reason: 'the slider under the scrim moved');
    });

    testWidgets('the identical drag works with no scrim', (tester) async {
      // The control half: proves the test above could have failed, rather than
      // the drag simply never landing.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);
      TutorialController.debugDisabled = true;
      var slid = 0;

      await pumpAt(
        tester,
        host(
          target: key,
          tutorial: tutorial,
          onPressed: () {},
          onSlide: (_) => slid++,
        ),
      );
      expect(tutorial.isRunning, isFalse);

      await tester.timedDrag(
        find.byType(Slider),
        const Offset(60, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump();

      expect(slid, greaterThan(0), reason: 'the drag never worked at all');
    });
  });

  group('refusing and advancing', () {
    testWidgets('a tap on the scrim nudges and does not advance', (
      tester,
    ) async {
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );
      expect(tutorial.nudges, 0);

      // Bottom of the screen, well clear of the hole.
      await tester.tapAt(const Offset(200, 700));
      await tester.pump();

      expect(tutorial.nudges, 1, reason: 'the refusal was not counted');
      expect(tutorial.current?.id, 'press', reason: 'a refusal advanced it');
    });

    testWidgets('an anywhere step advances from a tap on the hole', (
      tester,
    ) async {
      // Catches four blockers where there should be one: with four, the hole
      // is dead and the one place the player is told to look does nothing.
      //
      // The step's id is deliberately NOT the one the button reports. With
      // four blockers the tap falls through to the real button, which reports
      // 'press' - and if this step were also called 'press' it would advance
      // by the wrong route and the test would pass with the bug in place. It
      // did, until this was fixed.
      final key = GlobalKey();
      final tutorial = TutorialController(
        flag: 'anywhere.v1',
        everyTime: true,
        steps: <TutorialStep>[
          TutorialStep(
            id: 'look',
            targetKey: key,
            caption: 'This fills up on its own.',
            advance: TutorialAdvance.anywhere,
          ),
          TutorialStep(
            id: 'second',
            targetKey: key,
            caption: 'And here is the second lesson.',
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );
      expect(tutorial.current?.id, 'look');

      await tester.tapAt(tester.getCenter(find.text('REAL')));
      await tester.pump();

      expect(tutorial.current?.id, 'second');
    });
  });

  group('the caption', () {
    testWidgets('is narrower than the screen', (tester) async {
      // Catches the tight-constraints trap: a Positioned with both left and
      // right forces the panel full width whatever maxWidth it was given.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      final box = tester.getRect(find.byType(TypedText));
      expect(box.width, lessThan(phone.width));
      expect(box.width, lessThanOrEqualTo(kCaptionCapCompact));
    });

    testWidgets('sits below a target near the top', (tester) async {
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      final caption = tester.getRect(find.byType(TypedText));
      final hole = tester.getRect(find.text('REAL'));
      expect(caption.top, greaterThan(hole.bottom));
    });

    testWidgets('does not move while it types', (tester) async {
      // Catches a box that grows to fit, which crawls every frame and drags
      // the eye off the thing being pointed at.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      final first = tester.getRect(find.byType(TypedText));
      await tester.pump(const Duration(milliseconds: 120));
      final middle = tester.getRect(find.byType(TypedText));
      await tester.pump(const Duration(seconds: 2));
      final end = tester.getRect(find.byType(TypedText));

      expect(middle, first, reason: 'the caption box moved mid-type');
      expect(end, first, reason: 'the caption box moved by the end');
    });

    testWidgets('a refused tap does not restart the typing', (tester) async {
      // Catches the didUpdateWidget guard. The overlay rebuilds on every
      // refused tap; a refusal should replay the hand, but must not snatch
      // back a sentence somebody is halfway through reading.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      // Let it finish typing, then refuse a tap.
      await tester.pump(const Duration(seconds: 2));
      final settled = _revealed(tester);
      expect(settled, greaterThan(0));

      await tester.tapAt(const Offset(200, 700));
      await tester.pump();

      expect(tutorial.nudges, 1, reason: 'the refusal did not register');
      expect(
        _revealed(tester),
        settled,
        reason: 'the caption started typing again',
      );
    });

    testWidgets('is findable by its whole text while typing', (tester) async {
      // The tail is painted transparent rather than left out, so find.text
      // keeps working throughout - substring typing breaks every caption test
      // anyone writes later.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.text('Tap the real button to carry on.'), findsOneWidget);
    });
  });

  group('a window that changes size', () {
    testWidgets('keeps the caption on screen', (tester) async {
      // The app is landscape-locked but the window is not fixed: a resizable
      // window, a foldable, split screen and the rotation itself all change it
      // under a sequence that is already up.
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      // Its own host, laid out with Positioned so it cannot overflow at any
      // size - the shared one is a Column of fixed boxes and would report its
      // own overflow instead of the thing under test.
      await pumpAt(
        tester,
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!tutorial.isRunning) tutorial.start(context);
                });
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 20,
                      top: 20,
                      child: SizedBox(key: key, width: 100, height: 40),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      expect(find.byType(TypedText), findsOneWidget);

      const smaller = Size(512, 231);
      tester.view.physicalSize = smaller;
      // ONE frame, which is all a resize gives you.
      await tester.pump();

      final screen = Rect.fromLTWH(0, 0, smaller.width, smaller.height);
      final caption = tester.getRect(find.byType(TypedText));
      expect(
        screen.contains(caption.topLeft) && screen.contains(caption.bottomRight),
        isTrue,
        reason: 'caption at $caption fell outside the $screen window',
      );
    });
  });

  group('a target that arrives late', () {
    testWidgets('still lays the caption out on screen', (tester) async {
      // The path that bites in a real app: on the first frame the target is
      // not laid out, so the overlay draws nothing. The NEXT build then asks
      // for its own render object - and gets the one from that empty frame,
      // which is zero sized. A screen measured as 0x0 puts the caption off the
      // bottom edge and leaves the scrim without blockers.
      final key = GlobalKey();
      var showTarget = false;
      late StateSetter setOuter;

      final tutorial = TutorialController(
        flag: 'late.v1',
        everyTime: true,
        steps: <TutorialStep>[
          TutorialStep(
            id: 'press',
            targetKey: key,
            caption: 'Here it is at last.',
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!tutorial.isRunning) tutorial.start(context);
                });
                return Column(
                  children: <Widget>[
                    const SizedBox(height: 80),
                    if (showTarget)
                      SizedBox(key: key, width: 160, height: 60)
                    else
                      const SizedBox(width: 160, height: 60),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Now it appears, exactly as a Flame overlay or a late layout would.
      setOuter(() => showTarget = true);
      await tester.pump();
      await tester.pump();

      final screen = Rect.fromLTWH(0, 0, phone.width, phone.height);
      final caption = tester.getRect(find.byType(TypedText));
      expect(
        screen.contains(caption.topLeft) && screen.contains(caption.bottomRight),
        isTrue,
        reason: 'caption at $caption fell outside the $screen screen',
      );
    });
  });

  group('the hand', () {
    testWidgets('an anywhere step draws point, though it asked for tap', (
      tester,
    ) async {
      // Catches the gesture override being left to whoever writes the step. A
      // finger jabbing with ripples says "press this" while the caption says
      // "tap anywhere" - it points at the one place the instruction does not
      // mean, and the mistake is invisible in review.
      final key = GlobalKey();
      final seen = <HandGesture>[];
      final tutorial = TutorialController(
        flag: 'hand.v1',
        everyTime: true,
        hand: (_, spec) {
          seen.add(spec.gesture);
          return const SizedBox.shrink();
        },
        steps: <TutorialStep>[
          TutorialStep(
            id: 'look',
            targetKey: key,
            caption: 'Look at this.',
            // Deliberately asks for tap.
            gesture: HandGesture.tap,
            advance: TutorialAdvance.anywhere,
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      expect(seen, isNotEmpty, reason: 'the hand was never asked to draw');
      expect(seen.last, HandGesture.point);
    });

    testWidgets('a pointing hand does not lie across what it points at', (
      tester,
    ) async {
      // A point marks something to be READ. Aimed at the middle, the hand
      // covers the score or the hearts it is explaining - which looks like a
      // layout bug and hides the one thing the caption is talking about.
      final key = GlobalKey();
      final seen = <HandSpec>[];
      final tutorial = TutorialController(
        flag: 'hand.v3',
        everyTime: true,
        hand: (_, spec) {
          seen.add(spec);
          return const SizedBox.shrink();
        },
        steps: <TutorialStep>[
          TutorialStep(
            id: 'look',
            targetKey: key,
            caption: 'Look at this.',
            advance: TutorialAdvance.anywhere,
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      final hole = tester.getRect(find.byKey(key));
      final spec = seen.last;
      expect(spec.gesture, HandGesture.point);
      // The target is near the top, so the hand comes up from below and its
      // body falls down and to the right - which means the fingertip belongs
      // on the right edge, not in the middle.
      expect(spec.fromAbove, isFalse);
      expect(
        spec.tip.dx,
        greaterThanOrEqualTo(hole.right),
        reason: 'the hand is laid across the middle of its own target',
      );
    });

    testWidgets('a target step keeps the gesture it asked for', (tester) async {
      // The other half: the override must apply to anywhere steps only.
      final key = GlobalKey();
      final seen = <HandGesture>[];
      final tutorial = TutorialController(
        flag: 'hand.v2',
        everyTime: true,
        hand: (_, spec) {
          seen.add(spec.gesture);
          return const SizedBox.shrink();
        },
        steps: <TutorialStep>[
          TutorialStep(
            id: 'press',
            targetKey: key,
            caption: 'Press this.',
            gesture: HandGesture.tap,
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      expect(seen.last, HandGesture.tap);
    });
  });

  group('the sequence cannot leave a scrim behind', () {
    testWidgets('disposing the controller removes the overlay', (tester) async {
      final key = GlobalKey();
      final tutorial = build(key);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );
      expect(find.byType(TypedText), findsOneWidget);

      tutorial.dispose();
      await tester.pump();

      expect(find.byType(TypedText), findsNothing);
      expect(tutorial.isRunning, isFalse);
    });

    testWidgets('finishing the last step takes the scrim with it', (
      tester,
    ) async {
      final key = GlobalKey();
      final tutorial = build(key);
      addTearDown(tutorial.dispose);

      await pumpAt(
        tester,
        host(target: key, tutorial: tutorial, onPressed: () {}),
      );

      tutorial
        ..report('press')
        ..report('second');
      await tester.pump();

      expect(tutorial.isRunning, isFalse);
      expect(find.byType(TypedText), findsNothing);
    });
  });

  group('the store', () {
    test('a seen sequence does not start again', () async {
      final store = MemoryTutorialStore(<String>{'seen.v1'});
      final tutorial = TutorialController(
        flag: 'seen.v1',
        store: store,
        steps: <TutorialStep>[
          TutorialStep(
            id: 'a',
            targetKey: GlobalKey(),
            caption: 'Never shown.',
          ),
        ],
      );
      addTearDown(tutorial.dispose);

      expect(await store.hasSeen('seen.v1'), isTrue);
      expect(tutorial.isRunning, isFalse);
    });

    test('everyTime never reads the flag', () async {
      final store = MemoryTutorialStore(<String>{'repeat.v1'});
      final tutorial = TutorialController(
        flag: 'repeat.v1',
        everyTime: true,
        store: store,
        steps: <TutorialStep>[
          TutorialStep(id: 'a', targetKey: GlobalKey(), caption: 'Shown.'),
        ],
      );
      addTearDown(tutorial.dispose);

      // Finishing must not mark it, or "every time" becomes "once".
      tutorial.report('a');
      expect(await store.hasSeen('repeat.v1'), isTrue);
    });
  });
}

/// How many characters are currently painted in ink.
///
/// The caption lays out the whole line from the first frame and paints the
/// tail transparent, so "how far has it typed" is the length of the first span
/// rather than the length of the text.
int _revealed(WidgetTester tester) {
  final rich = tester.widget<Text>(
    find.descendant(of: find.byType(TypedText), matching: find.byType(Text)),
  );
  final span = rich.textSpan! as TextSpan;
  return (span.children!.first as TextSpan).text!.length;
}
