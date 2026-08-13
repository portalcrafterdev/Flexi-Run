import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/audio.dart';
import 'core/constants.dart';
import 'core/games.dart';
import 'core/prefs.dart';
import 'core/shape_kind.dart';
import 'game/shape_shifter_game.dart';
import 'ui/game_over_overlay.dart';
import 'ui/hud.dart';
import 'ui/menu_overlay.dart';
import 'ui/pause_overlay.dart';
import 'ui/shape_pad.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Prefs.init();
  await Audio.init();
  // Plays under the menu as well as the run; the Music toggle stops it.
  // Deliberately not awaited: nothing should delay the first frame.
  unawaited(Audio.startMusic());
  // Same again. The SDK takes a moment to start and then goes off to fetch an
  // ad; none of that may sit between launching and the menu appearing, and
  // nothing needs an ad until a run has already been played.
  unawaited(Ads.init());
  // Only listens for a session that already exists. It never prompts, so this
  // cannot put a sign-in sheet in front of a child who just opened the game.
  unawaited(Games.init());
  runApp(const ShapeShifterApp());
}

class ShapeShifterApp extends StatelessWidget {
  const ShapeShifterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flexi Run',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kUiAccent),
        useMaterial3: true,
      ),
      home: const GameHost(),
    );
  }
}

class GameHost extends StatefulWidget {
  const GameHost({super.key});

  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost> with WidgetsBindingObserver {
  /// Desktop shortcut for the shapes, in the same order as [ShapeKind.values]
  /// so a fourth shape only needs a fourth key here.
  static const _shapeKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  final ShapeShifterGame _game = ShapeShifterGame();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kids put phones down mid-run, so a backgrounded app never keeps playing.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _game.requestPause();
      // Everything, not just the music. A sound effect is a platform side
      // player that runs to the end of its clip on its own, so a coin taken
      // in the last moment before the home button used to chime over the
      // launcher after the game was gone.
      unawaited(Audio.suspend());
    } else if (state == AppLifecycleState.resumed) {
      // Let sound back in whatever happens: a player coming back to a game
      // they left parked still has a pause panel with two volume bars on it.
      Audio.wake();
      if (!_game.pauseNotifier.value) Audio.resumeMusic();
    }
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final index = _shapeKeys.indexOf(event.logicalKey);
    if (index >= 0 && index < ShapeKind.values.length) {
      _game.morph(ShapeKind.values[index]);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _game.stepLane(-1);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _game.stepLane(1);
      return;
    }
    final isStart =
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter;
    if (isStart &&
        (_game.state == GameState.menu || _game.state == GameState.gameOver)) {
      _game.startRun();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The overlays are plain Flutter widgets and need a Material ancestor:
    // without one their text falls back to the debug style and any list tile
    // throws. Transparent so the game keeps showing through.
    return Material(
      type: MaterialType.transparency,
      child: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: <Widget>[
            GameWidget<ShapeShifterGame>(
              game: _game,
              // The game takes no key input of its own; leaving focus with the
              // KeyboardListener above is what makes the 1/2/3 keys work.
              autofocus: false,
              overlayBuilderMap:
                  <String, Widget Function(BuildContext, ShapeShifterGame)>{
                    Overlays.menu: (_, game) => MenuOverlay(game: game),
                    Overlays.hud: (_, game) => Hud(game: game),
                    Overlays.pad: (_, game) => ShapePad(game: game),
                    Overlays.gameOver: (_, game) => GameOverOverlay(game: game),
                  },
            ),
            PausePanel(game: _game),
            // Last, so it stays above the pause panel and can be the thing
            // that unpauses.
            PauseToggle(game: _game),
          ],
        ),
      ),
    );
  }
}
