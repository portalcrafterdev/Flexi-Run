import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../game/shape_shifter_game.dart';
import 'panel.dart';
import 'sound_levels.dart';

/// The panel that covers a parked run.
///
/// Carries the sound and music bars as well as the buttons. Pausing is when a
/// game gets turned down: it is the moment a parent reaches for the phone, and
/// making them leave the run and go to the menu to do it is why so many
/// children's games end up muted at the system level instead.
///
/// Not a Flame overlay. It has to sit under the pause button in the app's own
/// stack, because the scrim swallows taps and the button has to stay reachable
/// to be the thing that unpauses.
class PausePanel extends StatelessWidget {
  const PausePanel({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.pauseNotifier,
      builder: (_, paused, _) =>
          paused ? _panel() : const SizedBox.shrink(),
    );
  }

  Widget _panel() => GamePanel(
    children: <Widget>[
      const PanelTitle('Paused'),
      const SizedBox(height: kMenuButtonGap * 0.5),
      ValueListenableBuilder<int>(
        valueListenable: game.score,
        builder: (_, score, _) => PanelScore(
          label: 'Score',
          value: score.toString().padLeft(kScoreDigits, '0'),
        ),
      ),
      const SizedBox(height: kMenuButtonGap * 0.7),
      const SoundLevels(compact: true),
      const SizedBox(height: kMenuButtonGap * 0.8),
      BigButton(label: 'KEEP GOING', onPressed: game.resumePlay),
      const SizedBox(height: kMenuButtonGap * 0.5),
      MenuButton(onPressed: game.goToMenu),
    ],
  );
}
