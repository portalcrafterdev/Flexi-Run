import 'dart:async';

import 'package:flutter/widgets.dart';

import '../game/shape_shifter_game.dart';
import 'flexirun_tutorial.dart';
import 'hand_indicator.dart';
import 'tutorial_controller.dart';
import 'tutorial_store.dart';

/// Starts and stops the coach marks around a run, and holds the world still
/// while they are up.
///
/// Draws nothing. The marks live in the root [Overlay], which is what lets
/// them sit above the Flame overlays, the pause panel and the pause button
/// without any of those knowing a tutorial exists.
class TutorialRunner extends StatefulWidget {
  const TutorialRunner({
    required this.game,
    required this.link,
    this.store,
    super.key,
  });

  final ShapeShifterGame game;
  final TutorialLink link;

  /// Overridden in tests. Left null in the app, where the controller reaches
  /// for shared_preferences itself.
  final TutorialStore? store;

  @override
  State<TutorialRunner> createState() => _TutorialRunnerState();
}

class _TutorialRunnerState extends State<TutorialRunner> {
  TutorialController? _controller;

  /// Which sequence [_controller] is running, so a second call for the same
  /// one is ignored and a call for a different one replaces it.
  String? _flag;

  @override
  void initState() {
    super.initState();
    widget.game.stateNotifier.addListener(_onGameState);
    // A run can already be under way when this is mounted - a hot reload, or a
    // host that builds this after the game has started.
    _onGameState();
  }

  @override
  void dispose() {
    widget.game.stateNotifier.removeListener(_onGameState);
    // Before the teardown, and unconditionally. A hold left set is a run in
    // which no wall ever spawns again, and nothing on screen would say why.
    widget.game.releaseFromTutorial();
    _teardown();
    super.dispose();
  }

  void _onGameState() {
    switch (widget.game.state) {
      case GameState.menu:
        // The home screen teaches too: which tile sets the difficulty, where
        // the instructions are, and which button starts the game.
        _begin(kMenuTutorialFlag, widget.link.menuSteps(), hold: false);
      case GameState.running:
        final level = widget.game.level.value;
        _begin(
          tutorialFlagFor(level),
          widget.link.stepsFor(level),
          hold: true,
        );
      case GameState.hit:
        // Left alone. A hit cannot happen while the marks are up - nothing
        // closes in - so this is the freeze frame of an ordinary run, and
        // tearing down here would end a sequence that is not running anyway.
        break;
      case GameState.gameOver:
        widget.game.releaseFromTutorial();
        _teardown();
    }
  }

  /// Starts [flag]'s sequence, replacing any other that is up.
  ///
  /// [hold] stops the world while the marks are shown. True for a run, where
  /// a wall would otherwise arrive mid-lesson; false on the menu, where
  /// nothing is coming.
  void _begin(String flag, List<TutorialStep> steps, {required bool hold}) {
    // Already running this one. Not a no-op for every call: the menu sequence
    // must give way to the run's the moment a run starts.
    if (_controller != null && _flag == flag) return;
    if (_controller != null) {
      widget.game.releaseFromTutorial();
      _teardown();
    }

    final controller = TutorialController(
      flag: flag,
      steps: steps,
      hand: (context, spec) => HandIndicator(spec: spec),
      store: widget.store,
    );
    _controller = controller;
    _flag = flag;
    widget.link.bind(controller);
    controller.addListener(_onTutorialChanged);

    // Held before the flag is read, not after. Reading it is a round trip to
    // storage, and a wall arriving inside that window would be one the player
    // was never shown how to pass.
    if (hold) widget.game.holdForTutorial();

    // After the frame: the HUD and the pad are Flame overlays, and a mark
    // cannot be measured from a target that has not been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller != controller) return;
      unawaited(_startNow(controller));
    });
  }

  Future<void> _startNow(TutorialController controller) async {
    // The game first. Every target these marks point at lives in an overlay
    // the engine mounts once it has loaded, and this runs from initState -
    // well before that. Starting here put the sequence in front of a screen
    // that did not exist yet, where it sat looking for a target and then gave
    // up on one that was moments away.
    if (!widget.game.isLoaded) {
      await widget.game.loaded;
      if (!mounted || _controller != controller) return;
    }
    await controller.startIfUnseen(context);
    // Still the current one: a run can end inside that await.
    if (!mounted || _controller != controller) return;
    // Seen already, or refused. Either way the run must not stay held.
    if (!controller.isRunning) {
      widget.game.releaseFromTutorial();
      _teardown();
    }
  }

  void _onTutorialChanged() {
    final controller = _controller;
    if (controller == null || controller.isRunning) return;
    widget.game.releaseFromTutorial();
    // Deferred, because this is reached from inside the controller's own
    // notifyListeners and ChangeNotifier asserts against being disposed while
    // its listener list is being walked. Nothing is on screen in the meantime:
    // the sequence takes its overlay entry down before it notifies.
    _teardown(defer: true);
  }

  void _teardown({bool defer = false}) {
    final controller = _controller;
    if (controller == null) return;
    // Cleared first, so the dispose below cannot re-enter through the listener.
    _controller = null;
    _flag = null;
    widget.link.bind(null);
    controller.removeListener(_onTutorialChanged);
    if (defer) {
      scheduleMicrotask(controller.dispose);
    } else {
      // Straight away on the paths that are not inside a notification - and it
      // has to be, because this is one of them: a deferred dispose from
      // State.dispose would reach for an Overlay that has already gone.
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
