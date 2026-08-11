import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'core/constants.dart';
import 'core/prefs.dart';
import 'core/shape_kind.dart';
import 'game/shape_shifter_game.dart';
import 'ui/game_over_overlay.dart';
import 'ui/hud.dart';
import 'ui/menu_overlay.dart';
import 'ui/panel.dart';
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
      Audio.pauseMusic();
    } else if (state == AppLifecycleState.resumed &&
        !_game.pauseNotifier.value) {
      Audio.resumeMusic();
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
            ValueListenableBuilder<bool>(
              valueListenable: _game.pauseNotifier,
              builder: (_, paused, _) => paused
                  ? GamePanel(
                      children: <Widget>[
                        const PanelTitle('Paused'),
                        const SizedBox(height: kMenuButtonGap * 0.6),
                        ValueListenableBuilder<int>(
                          valueListenable: _game.score,
                          builder: (_, score, _) => PanelScore(
                            label: 'Score',
                            value: score
                                .toString()
                                .padLeft(kScoreDigits, '0'),
                          ),
                        ),
                        const SizedBox(height: kMenuButtonGap),
                        BigButton(
                          label: 'KEEP GOING',
                          onPressed: _game.resumePlay,
                        ),
                        const SizedBox(height: kMenuButtonGap * 0.6),
                        MenuButton(onPressed: _game.goToMenu),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
