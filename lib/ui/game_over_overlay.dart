import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../game/shape_shifter_game.dart';
import 'panel.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    final beatIt = game.score.value >= game.highScore.value &&
        game.score.value > 0;
    return GamePanel(
      children: <Widget>[
        // Never "game over": the run ended, and the next one starts from the
        // same button. Six year olds put the phone down when told they lost.
        PanelTitle(beatIt ? 'New best!' : 'Good run!'),
        const SizedBox(height: kMenuButtonGap * 0.6),
        ValueListenableBuilder<int>(
          valueListenable: game.score,
          builder: (_, score, _) => PanelScore(
            label: 'Score',
            value: score.toString(),
            highlight: beatIt,
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: game.highScore,
          // Named, because the best is per level: without it the number looks
          // like an all-time best that Easy has quietly been beating. Not
          // padded, unlike the score above it: that one is a readout holding
          // its width, this is a fact.
          builder: (_, high, _) =>
              PanelLine('${game.level.value.label} best  $high'),
        ),
        const SizedBox(height: kMenuButtonGap),
        BigButton(label: 'PLAY AGAIN', onPressed: game.startRun),
        const SizedBox(height: kMenuButtonGap * 0.6),
        MenuButton(onPressed: game.goToMenu),
      ],
    );
  }
}
