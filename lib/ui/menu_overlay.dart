import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/audio.dart';
import '../core/constants.dart';
import '../game/shape_shifter_game.dart';
import 'banner_slot.dart';
import 'level_picker.dart';
import 'menu_background.dart';
import 'menu_logo.dart';
import 'menu_runner.dart';
import 'menu_widgets.dart';
import 'sound_levels.dart';

/// The home screen: a name, a character, and the things you can press.
///
/// Laid out across the screen rather than stacked down the middle of it. The
/// phone is held sideways, which makes the screen wide and short, and a single
/// 330 point column in the centre of that left two thirds of the picture as
/// empty field - the menu read as a form someone had dropped onto a landscape.
/// So: the name up in the top left, the runner standing on the hill below it,
/// and everything pressable gathered in one column on the right, where the
/// thumb holding the phone already is.
class MenuOverlay extends StatefulWidget {
  const MenuOverlay({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

enum _Sheet { none, settings, howTo }

const _kTagline = 'Match the shape and slip through the wall!';

class _MenuOverlayState extends State<MenuOverlay> {
  _Sheet _sheet = _Sheet.none;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: RepaintBoundary(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: MenuBackground()),
            _body(),
            // Laid over the bottom of the scene rather than given a row of
            // its own. Taking the height out of the layout was worse than it
            // sounds: the menu dropped under the threshold for the spread,
            // fell back to one centred column, and the runner disappeared -
            // an advert loading rearranged the home screen. It sits below
            // everything the layout puts on screen, over empty grass.
            const Align(
              alignment: Alignment.bottomCenter,
              child: BannerSlot(),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                // Held well clear of the top edge. Right against it, a tap
                // aimed at the gear drags the system notification shade down
                // instead, which on a phone in immersive mode is most of the
                // top strip.
                minimum: const EdgeInsets.only(
                  top: kEdgeGestureInset,
                  right: kHudPad / 2,
                ),
                child: _GearButton(onPressed: () => _open(_Sheet.settings)),
              ),
            ),
            if (_sheet == _Sheet.settings) _settingsSheet(),
            if (_sheet == _Sheet.howTo) _howToSheet(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(
        horizontal: kOverlayPad,
        vertical: kOverlayPad / 2,
      ),
      child: LayoutBuilder(
        builder: (_, box) {
          // Both dimensions have to be there: a short landscape phone is wide
          // enough for the spread but cannot hold the runner and the buttons
          // at the same time.
          final spread =
              box.maxWidth >= kMenuWideW && box.maxHeight >= kMenuWideH;
          return spread
              ? _Spread(
                  game: widget.game,
                  height: box.maxHeight,
                  onPlay: _play,
                  onHowTo: () => _open(_Sheet.howTo),
                )
              : Center(
                  child: SingleChildScrollView(
                    child: _Stacked(
                      game: widget.game,
                      onPlay: _play,
                      onHowTo: () => _open(_Sheet.howTo),
                    ),
                  ),
                );
        },
      ),
    );
  }

  // The same bars the pause panel carries, so the two can never disagree.
  Widget _settingsSheet() => MenuSheet(
    title: 'Settings',
    onClose: _close,
    children: const <Widget>[SoundLevels()],
  );

  Widget _howToSheet() => MenuSheet(
    title: 'How to play',
    onClose: _close,
    children: const <Widget>[
      MenuStep(number: 1, text: 'A wall comes down the path with a hole in it.'),
      MenuStep(number: 2, text: 'Tap the shape that matches the hole.'),
      MenuStep(number: 3, text: 'Use the arrows to get onto the right track.'),
      MenuStep(number: 4, text: 'Fit through, and keep going!'),
    ],
  );

  /// PLAY goes through the same door the game over panel's PLAY AGAIN does, so
  /// the interstitial pacing counts every run once however the player got
  /// here - rather than being skippable by taking the long way round.
  void _play() => unawaited(Ads.beforeRun(widget.game.startRun));

  void _open(_Sheet sheet) => setState(() => _sheet = sheet);

  void _close() => setState(() => _sheet = _Sheet.none);
}

/// The landscape layout: name top left, runner bottom left, controls right.
class _Spread extends StatelessWidget {
  const _Spread({
    required this.game,
    required this.height,
    required this.onPlay,
    required this.onHowTo,
  });

  final ShapeShifterGame game;
  final double height;
  final VoidCallback onPlay;
  final VoidCallback onHowTo;

  @override
  Widget build(BuildContext context) {
    // Sized off the height rather than fixed, so a short phone gets a smaller
    // runner instead of one with its feet off the bottom of the screen.
    final runner = min(kMenuRunnerBox, height * kMenuRunnerShare);
    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: kMenuBrandInset),
              child: _Brand(),
            ),
          ),
          Align(
            alignment: const Alignment(kMenuRunnerAcross, 1),
            child: MenuRunner(size: runner),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: kMenuColumnW,
              child: _Controls(
                game: game,
                onPlay: onPlay,
                onHowTo: onHowTo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fallback: one centred column, for anything too small for the spread.
class _Stacked extends StatelessWidget {
  const _Stacked({
    required this.game,
    required this.onPlay,
    required this.onHowTo,
  });

  final ShapeShifterGame game;
  final VoidCallback onPlay;
  final VoidCallback onHowTo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMenuColumnW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Center(child: _Brand(compact: true)),
          const SizedBox(height: kMenuButtonGap),
          _Controls(game: game, onPlay: onPlay, onHowTo: onHowTo),
        ],
      ),
    );
  }
}

/// The name and what the game is.
class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        GameLogo(
          'FLEXI RUN',
          fontSize: compact ? kLogoSizeNarrow : kLogoSize,
        ),
        const SizedBox(height: kMenuButtonGap * 0.6),
        const TaglinePill(_kTagline),
      ],
    );
  }
}

/// Everything that can be pressed, in one column.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.game,
    required this.onPlay,
    required this.onHowTo,
  });

  final ShapeShifterGame game;
  final VoidCallback onPlay;
  final VoidCallback onHowTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Above PLAY, because this is what a parent comes to the menu to set,
        // and PLAY is unmissable wherever it sits.
        LevelPicker(game: game),
        // Wider than the gap between the two slabs: the pills cast a shadow of
        // their own and PLAY casts one upwards onto them, so a tight gap here
        // leaves the pills looking smudged along the bottom.
        const SizedBox(height: kMenuButtonGap * 1.5),
        ChunkyButton(
          label: 'PLAY',
          icon: Icons.play_arrow_rounded,
          fill: kPlayFill,
          edge: kPlayEdge,
          onPressed: onPlay,
        ),
        const SizedBox(height: kMenuButtonGap * 0.6),
        ChunkyButton(
          label: 'HOW TO PLAY',
          icon: Icons.lightbulb_rounded,
          fill: kHowToFill,
          edge: kHowToEdge,
          onPressed: onHowTo,
        ),
      ],
    );
  }
}

// The stats pill that used to sit under the buttons is gone. The best score
// still has a home: each level button carries its own, and the game over panel
// names it at the moment it actually means something.

class _GearButton extends StatelessWidget {
  const _GearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Audio.tap();
          onPressed();
        },
        child: Container(
          width: kMinTapTarget / 2,
          height: kMinTapTarget / 2,
          decoration: const BoxDecoration(
            color: kMenuCard,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: kMenuShadow, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: kMenuStat,
            size: kMenuIconSize,
          ),
        ),
      ),
    );
  }
}
