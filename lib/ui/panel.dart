import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'menu_widgets.dart';

/// The card the pause and game over screens sit in.
///
/// The same rimmed card and chunky slabs as the menu, so stopping mid-run
/// lands somewhere that looks like the same game rather than a system dialog
/// that happens to have appeared over it.
class GamePanel extends StatelessWidget {
  const GamePanel({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kUiScrim,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kOverlayPad / 2),
            child: SizedBox(
              // Max, not fixed: the card has to shrink on narrow screens
              // rather than overflow them.
              width: kMenuColumnW,
              child: MenuCard(
                padding: kOverlayPad * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The green slab every panel leads with.
class BigButton extends StatelessWidget {
  const BigButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChunkyButton(
    label: label,
    icon: icon,
    fill: kPlayFill,
    edge: kPlayEdge,
    onPressed: onPressed,
  );
}

/// The blue slab that leaves, next to whichever green one carries on.
class MenuButton extends StatelessWidget {
  const MenuButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChunkyButton(
    label: 'MENU',
    icon: Icons.home_rounded,
    fill: kHowToFill,
    edge: kHowToEdge,
    onPressed: onPressed,
  );
}

class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: kPanelTitleSize,
        fontWeight: FontWeight.w900,
        color: kUiInk,
        height: 1.1,
      ),
    );
  }
}

/// A score, big enough to be the thing you look at.
class PanelScore extends StatelessWidget {
  const PanelScore({
    required this.label,
    required this.value,
    this.highlight = false,
    super.key,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kMenuButtonGap * 0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (highlight) ...<Widget>[
            const Icon(
              Icons.star_rounded,
              size: kMenuIconSize,
              color: kMenuCardEdge,
            ),
            const SizedBox(width: kMenuButtonGap * 0.5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: kMenuTaglineSize,
              fontWeight: FontWeight.w700,
              color: kMenuTagline,
            ),
          ),
          const SizedBox(width: kMenuButtonGap),
          Text(
            value,
            style: TextStyle(
              fontSize: kPanelScoreSize,
              fontWeight: FontWeight.w900,
              color: highlight ? kPlayEdge : kUiInk,
            ),
          ),
        ],
      ),
    );
  }
}

class PanelLine extends StatelessWidget {
  const PanelLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: kMenuTaglineSize,
        fontWeight: FontWeight.w600,
        color: kMenuTagline,
      ),
    );
  }
}
