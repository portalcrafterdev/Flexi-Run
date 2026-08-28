import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/audio.dart';
import '../core/boards.dart';
import '../core/constants.dart';
import '../core/games.dart';
import '../game/shape_shifter_game.dart';
import 'menu_widgets.dart';
import 'panel.dart';

/// The end of a run: what you scored, and the three ways out of it.
///
/// A second chance is offered here and nowhere else, because this is the only
/// moment it is worth anything. It is the first button on the panel but not
/// the loudest: PLAY AGAIN stays green and free, and a child who does not want
/// to watch anything can ignore the gold one entirely.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  /// True while an ad is on screen, so a second press cannot ask for a second
  /// one. Small hands press twice.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final beatIt =
        game.score.value >= game.highScore.value && game.score.value > 0;
    // Both halves have to hold: the run must not have spent its second chance
    // already, and there must be an ad in hand right now. Offering a reward
    // and then failing to produce one is worse than never offering it.
    final canRevive = !_busy && game.canOfferExtraLife && Ads.hasExtraLifeAd;

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
          builder: (_, high, _) {
            final line = PanelLine('${game.level.value.label} best  $high');
            // Tappable only where there is a board to open and someone signed
            // in to appear on it. Nothing is added to the panel otherwise: a
            // dead control next to a child's score is worse than no control,
            // and the layout must not move depending on who is signed in.
            if (!Games.isSignedIn || Board.forLevel(game.level.value) == null) {
              return line;
            }
            return Semantics(
              button: true,
              label: 'Show leaderboards',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Audio.tap();
                  unawaited(Games.showLeaderboards());
                },
                child: line,
              ),
            );
          },
        ),
        const SizedBox(height: kMenuButtonGap),
        if (canRevive) ...<Widget>[
          ChunkyButton(
            // Says the word "ad". "Watch for a life" reads like something the
            // game gives you; a child pressing this is agreeing to sit through
            // an advert, and the button should be the thing that says so.
            label: 'WATCH AD FOR A LIFE',
            icon: Icons.favorite_rounded,
            fill: kRewardFill,
            edge: kRewardEdge,
            onPressed: _watchForLife,
          ),
          const SizedBox(height: kMenuButtonGap * 0.6),
        ],
        BigButton(label: 'PLAY AGAIN', onPressed: _playAgain),
        const SizedBox(height: kMenuButtonGap * 0.6),
        MenuButton(onPressed: game.goToMenu),
      ],
    );
  }

  Future<void> _watchForLife() async {
    if (_busy) return;
    setState(() => _busy = true);

    // Held onto before the await, and used afterwards without asking whether
    // this widget is still mounted.
    //
    // A rewarded ad hands the screen to another activity, and this overlay can
    // be disposed and rebuilt while it is up. Guarding the result on `mounted`
    // - the reflex, and what this did at first - threw away the life the
    // player had just sat through an advert to earn: the ad played, the reward
    // arrived, and the panel came back exactly as it was. The game outlives
    // the panel, and the game is the thing that needs telling.
    final game = widget.game;
    final earned = await Ads.showExtraLifeAd();
    if (earned) {
      game.reviveWithExtraLife();
      return;
    }

    // Closed early, or the ad failed. No life and no penalty: the panel is
    // still here with PLAY AGAIN on it, which is where they were anyway.
    if (mounted) setState(() => _busy = false);
  }

  void _playAgain() {
    if (_busy) return;
    // The interstitial rides on this press rather than firing the moment the
    // last life goes. A full screen ad that arrives unbidden on the frame a
    // child loses steals the score they were about to read, and an ad nobody
    // asked for is exactly what the Families policy is about.
    unawaited(Ads.beforeRun(widget.game.startRun));
  }
}
