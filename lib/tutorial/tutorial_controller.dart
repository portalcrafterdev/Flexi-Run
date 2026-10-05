import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tutorial_overlay.dart';
import 'tutorial_store.dart';

/// How a coach mark is satisfied.
enum TutorialAdvance {
  /// The player has to do the thing. Everything but the hole is blocked, and a
  /// tap on the scrim is refused rather than counted. This is what makes the
  /// sequence teach instead of narrate.
  target,

  /// The step is explaining something that cannot be pressed - a score, a
  /// meter, a clock. A tap anywhere moves on.
  ///
  /// Without this, such a thing could only be explained by a step waiting
  /// forever for an interaction the widget does not offer.
  anywhere,
}

/// What the hand is doing over the target.
enum HandGesture { tap, swipe, point }

/// One coach mark.
@immutable
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.targetKey,
    required this.caption,
    this.gesture = HandGesture.tap,
    this.advance = TutorialAdvance.target,
    this.travel = Offset.zero,
    this.holeRadius = 18,
    this.holePadding = 8,
  });

  /// What [TutorialController.report] is called with when this is done.
  final String id;

  /// The real widget this mark is about. Must be mounted when the step runs.
  final GlobalKey targetKey;

  final String caption;
  final HandGesture gesture;
  final TutorialAdvance advance;

  /// For [HandGesture.swipe]: how far, and which way, the hand travels.
  ///
  /// Carried here rather than baked into the animation, because a Lottie file
  /// fixes its motion at author time - rotating a baked horizontal sweep to
  /// point downward lays the hand on its side.
  final Offset travel;

  final double holeRadius;
  final double holePadding;
}

/// Drives a sequence of coach marks over whatever is already on screen.
///
/// Owns an [OverlayEntry] and nothing else. It does not wrap the screen, does
/// not intercept its gestures and does not proxy any handler: the real button
/// keeps its real onTap and simply calls [report] afterwards.
///
/// That is the whole design. The alternative - the tutorial standing in front
/// of the screen and synthesising the press - gives every control two code
/// paths, and the taught one is the path nobody tests.
class TutorialController extends ChangeNotifier {
  TutorialController({
    required this.flag,
    required this.steps,
    this.everyTime = false,
    this.hand,
    TutorialStore? store,
  }) : _store = store ?? debugStore ?? const PrefsTutorialStore();

  /// Versioned, so a rewritten sequence can be shown again to somebody who
  /// saw the old one.
  final String flag;

  final List<TutorialStep> steps;

  /// Shown on every launch rather than once. Worth it for sequences that teach
  /// the controls: somebody returning after a month is being taught, not
  /// reminded.
  final bool everyTime;

  /// Draws the pointing hand. Injected, so this package stays copyable and so
  /// the sequence still runs - minus the hand - before an animation has been
  /// chosen for it.
  final Widget Function(BuildContext, HandSpec)? hand;

  final TutorialStore _store;

  /// The store every controller built after this is set will use.
  @visibleForTesting
  static TutorialStore? debugStore;

  /// Stops every sequence starting. An [everyTime] sequence cannot be turned
  /// off by seeding a flag, and a scrim over a test about something else
  /// blocks the very taps that test is making.
  @visibleForTesting
  static bool debugDisabled = false;

  OverlayEntry? _entry;
  int _index = 0;
  int _nudges = 0;
  /// When the current step first failed to find its target, on the frame
  /// clock.
  ///
  /// Elapsed time, not a frame count. Frames are not a fair budget at startup:
  /// the engine can pump a great many of them while a game is still loading
  /// its art, so a frame budget expired before the screen being taught had
  /// even been built - and the sequence gave up on a target that was moments
  /// away.
  ///
  /// The FRAME clock rather than a Stopwatch, because a Stopwatch reads real
  /// time, which a widget test cannot advance - the give-up would then never
  /// fire under test and the loop it exists to stop would hang the suite.
  Duration? _waitingSince;
  bool _running = false;

  /// A give-up is already scheduled for the end of this frame.
  bool _givingUp = false;

  bool get isRunning => _running;

  TutorialStep? get current =>
      _running && _index < steps.length ? steps[_index] : null;

  /// Counts refused taps on the scrim. The overlay keys the hand off this, so
  /// a refusal replays the gesture.
  int get nudges => _nudges;

  /// Starts unless this sequence has been seen.
  ///
  /// The flag is read before anything is inserted or paused. The other order -
  /// hold the screen, then await the read - makes that read a single point of
  /// failure for the whole screen.
  Future<void> startIfUnseen(BuildContext context) async {
    if (_running || debugDisabled) return;
    if (!everyTime && await _store.hasSeen(flag)) return;
    if (!context.mounted) return;
    start(context);
  }

  /// Starts now, from the top, whatever has gone before.
  ///
  /// Restarts rather than refuses: the controller outlives the screen, so one
  /// left part-finished would otherwise never run again and the lessons would
  /// appear exactly once.
  void start(BuildContext context) {
    if (debugDisabled || steps.isEmpty) return;
    _entry?.remove();
    _entry = null;
    _index = 0;
    _nudges = 0;
    _waitingSince = null;
    _givingUp = false;
    _running = true;

    final entry = OverlayEntry(
      builder: (_) => TutorialOverlay(controller: this, hand: hand),
    );
    _entry = entry;
    // rootOverlay, so the marks sit above anything the screen has pushed - a
    // dialog, a sheet, a route of its own.
    Overlay.of(context, rootOverlay: true).insert(entry);
    notifyListeners();
  }

  /// Tells the sequence that [id] happened.
  ///
  /// Ignores anything that is not the current step, and returns at once when
  /// nothing is running - so a call site never has to ask whether a tutorial
  /// is up. A handler guarded by `if (tutorial.isRunning)` is one that will
  /// one day be wrong.
  void report(String id) {
    if (!_running) return;
    if (current?.id != id) return;
    _advance();
  }

  /// A tap on the scrim, where the step wanted a tap on the target.
  ///
  /// Refused, not counted: it replays the hand and nothing else.
  void nudge() {
    if (!_running) return;
    _nudges++;
    notifyListeners();
  }

  /// For [TutorialAdvance.anywhere] steps, where any tap moves on.
  void advanceAnywhere() {
    if (!_running || current?.advance != TutorialAdvance.anywhere) return;
    _advance();
  }

  /// Ends the sequence early, marking it seen.
  void skip() => _finish();

  /// Asks the overlay to look again for a target that was not laid out yet.
  void refresh() {
    if (_running) notifyListeners();
  }

  /// The overlay could not measure the current step's target.
  ///
  /// Returns true while it is still worth looking again. A step whose target
  /// never arrives - a control that is only built when signed in, a screen
  /// that moved on - would otherwise sit in a post-frame callback scheduling
  /// another post-frame callback for as long as the app is open: a permanent
  /// rebuild loop with nothing on screen to show for it, and nothing to say
  /// what is wrong.
  ///
  /// Giving up does NOT mark the sequence seen. A target that was merely late
  /// should cost this launch's lesson, not every future one.
  bool awaitTarget() {
    if (!_running || _givingUp) return false;
    final now = WidgetsBinding.instance.currentFrameTimeStamp;
    final since = _waitingSince ??= now;
    if (now - since < kTargetWait) return true;
    // After the frame, not now. This is called from inside the overlay's
    // build, and ending the sequence notifies listeners - which is exactly
    // the "setState() called during build" that the framework asserts on.
    _givingUp = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _stop(seen: false));
    return false;
  }

  void _advance() {
    _index++;
    _nudges = 0;
    _waitingSince = null;
    _givingUp = false;
    if (_index >= steps.length) {
      _finish();
      return;
    }
    notifyListeners();
  }

  void _finish() => _stop(seen: true);

  /// Ends the sequence. [seen] records it as done, so it is not shown again.
  void _stop({required bool seen}) {
    if (!_running) return;
    _running = false;
    _entry?.remove();
    _entry = null;
    if (seen && !everyTime) unawaited(_store.markSeen(flag));
    notifyListeners();
  }

  @override
  void dispose() {
    // An overlay outliving its controller is an undismissable black screen
    // with no way out.
    _entry?.remove();
    _entry = null;
    _running = false;
    super.dispose();
  }
}
