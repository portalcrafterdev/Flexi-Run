import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/shape_kind.dart';
import '../game/shape_shifter_game.dart';
import 'level_picker.dart';
import 'menu_background.dart';
import 'menu_widgets.dart';
import 'shape_glyph.dart';
import 'sound_levels.dart';

/// The home screen: a title card and two slabs, over the live world.
///
/// No background of its own. The sky, the path and the scenery keep drifting
/// behind it, so pressing PLAY looks like stepping into somewhere that was
/// already there rather than loading a new screen.
class MenuOverlay extends StatefulWidget {
  const MenuOverlay({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

enum _Sheet { none, settings, howTo }

class _MenuOverlayState extends State<MenuOverlay> {
  _Sheet _sheet = _Sheet.none;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: RepaintBoundary(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: MenuBackground()),
            SafeArea(
              minimum: const EdgeInsets.all(kOverlayPad / 2),
              child: Center(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: kMenuColumnW,
                    child: _Home(
                      game: widget.game,
                      onPlay: widget.game.startRun,
                      onHowTo: () => _open(_Sheet.howTo),
                    ),
                  ),
                ),
              ),
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

  void _open(_Sheet sheet) => setState(() => _sheet = sheet);

  void _close() => setState(() => _sheet = _Sheet.none);
}

class _Home extends StatelessWidget {
  const _Home({
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
        MenuCard(
          padding: kOverlayPad * 0.7,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const RainbowTitle('FLEXI RUN'),
              const SizedBox(height: kMenuButtonGap * 0.6),
              const _Tagline(),
            ],
          ),
        ),
        const SizedBox(height: kMenuButtonGap * 0.7),
        // Above PLAY, because this is what a parent comes to the menu to set,
        // and PLAY is unmissable wherever it sits.
        LevelPicker(game: game),
        const SizedBox(height: kMenuButtonGap * 0.7),
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

/// The shapes, then what to do with them.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final kind in ShapeKind.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kMenuRuleGap),
                child: ShapeGlyph(
                  kind: kind,
                  // Each shape in its own title colour, so the mark and the
                  // name are visibly the same family.
                  color: kTitleLetterColors[kind.index %
                      kTitleLetterColors.length],
                  size: kMenuRuleGlyph,
                ),
              ),
          ],
        ),
        const SizedBox(height: kMenuButtonGap * 0.5),
        const Text(
          'Match the shape and slip through the wall!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: kMenuTaglineSize,
            fontWeight: FontWeight.w600,
            color: kMenuTagline,
          ),
        ),
      ],
    );
  }
}

// The stats pill that used to sit under the buttons is gone. The best score
// still has a home: the game over panel names it, per level, at the moment it
// actually means something.

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
        onTap: onPressed,
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
