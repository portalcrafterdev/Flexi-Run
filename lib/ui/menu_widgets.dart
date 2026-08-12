import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';

/// A solid slab with a darker lip under it, which sinks onto the lip when
/// pressed.
///
/// The lip is the whole point: a flat rectangle has to be learned as a button,
/// but a thing with a visible thickness reads as pressable to a child who
/// cannot yet read the label on it.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.edge,
    required this.onPressed,
    this.ink = kMenuButtonInk,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color edge;
  final Color ink;
  final VoidCallback onPressed;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Clicked on the way down, with the press, rather than on release:
        // the sound is confirmation that the button took the touch.
        onTapDown: (_) {
          setState(() => _down = true);
          Audio.tap();
        },
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          setState(() => _down = false);
          widget.onPressed();
        },
        child: SizedBox(
          height: kMenuButtonH + kChunkyDepth,
          child: Stack(
            children: <Widget>[
              // The lip, always at the bottom of the box. The face slides down
              // onto it rather than the whole button moving, so the button
              // never shifts the layout around it.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: kMenuButtonH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.edge,
                    borderRadius: BorderRadius.circular(kMenuButtonRadius),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: _down ? kChunkyDepth : 0,
                height: kMenuButtonH,
                child: _Face(
                  label: widget.label,
                  icon: widget.icon,
                  fill: widget.fill,
                  ink: widget.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.label,
    required this.icon,
    required this.fill,
    required this.ink,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(kMenuButtonRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: kMenuIconSize, color: ink),
          const SizedBox(width: kMenuButtonGap),
          Text(
            label,
            style: TextStyle(
              fontSize: kMenuButtonFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: kMenuButtonSpacing,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded card with a gold rim, the container everything on the menu that
/// is not a button sits in.
class MenuCard extends StatelessWidget {
  const MenuCard({
    required this.child,
    this.rimmed = true,
    this.padding = kOverlayPad,
    super.key,
  });

  final Widget child;
  final bool rimmed;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: rimmed ? kMenuCard : kSheetFill,
        borderRadius: BorderRadius.circular(kMenuCardRadius),
        border: Border.all(
          color: rimmed ? kMenuCardEdge : kSheetEdge,
          width: rimmed ? 3 : 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: kMenuShadow, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// The game name, a different colour on every letter.
class RainbowTitle extends StatelessWidget {
  const RainbowTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    var colour = 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final letter in text.split(''))
          Text(
            letter,
            style: TextStyle(
              fontSize: kMenuTitleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: kMenuTitleSpacing,
              height: 1,
              // Spaces keep their slot but do not take a colour, so the two
              // words do not restart the sequence.
              color: letter == ' '
                  ? const Color(0x00000000)
                  : kTitleLetterColors[colour++ % kTitleLetterColors.length],
            ),
          ),
      ],
    );
  }
}

/// A white card over the world, for settings and the how-to.
class MenuSheet extends StatelessWidget {
  const MenuSheet({
    required this.title,
    required this.onClose,
    required this.children,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Tapping off the card closes it, which is what a child will try.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const ColoredBox(
            color: kUiScrim,
            child: SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kOverlayPad),
              child: SizedBox(
                width: kMenuColumnW,
                child: MenuCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: kPanelTitleSize,
                          fontWeight: FontWeight.w900,
                          color: kUiInk,
                        ),
                      ),
                      const SizedBox(height: kMenuButtonGap),
                      ...children,
                      const SizedBox(height: kMenuButtonGap),
                      ChunkyButton(
                        label: 'DONE',
                        icon: Icons.check_rounded,
                        fill: kPlayFill,
                        edge: kPlayEdge,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One level: a tinted strip with a coloured icon, its name, and a bar.
///
/// A bar rather than a switch, because off is just the bottom of it. One
/// control instead of two, and a parent who wants the game quiet rather than
/// silent now has somewhere to say so.
class MenuLevel extends StatelessWidget {
  const MenuLevel({
    required this.label,
    required this.icon,
    required this.mutedIcon,
    required this.tint,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Shown at zero, so the row says "off" without needing to be read.
  final IconData mutedIcon;
  final Color tint;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: kMenuButtonGap * 0.7),
      padding: const EdgeInsets.all(kSettingRowPad),
      decoration: BoxDecoration(
        color: kSettingRowFill,
        borderRadius: BorderRadius.circular(kSettingRowRadius),
        border: Border.all(color: kSettingRowEdge, width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: kSettingBadge,
            height: kSettingBadge,
            decoration: BoxDecoration(
              // Dimmed at zero, so the state reads from across the room and
              // not only from where the bar happens to sit.
              color: on ? tint : tint.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              on ? icon : mutedIcon,
              size: kMenuIconSize,
              color: kMenuButtonInk,
            ),
          ),
          const SizedBox(width: kMenuButtonGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: kMenuTaglineSize,
                    fontWeight: FontWeight.w800,
                    color: kUiInk,
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: kLevelBarH,
                    activeTrackColor: tint,
                    inactiveTrackColor: kSwitchOffFill,
                    thumbColor: kSwitchThumbColor,
                    overlayColor: tint.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: kLevelThumb,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: kLevelThumb * 1.7,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                    // Nothing to show above the thumb: the icon already says
                    // whether it is on, and a number means little at six.
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: onChanged,
                    // Coarse steps. A continuous bar is fiddly for small
                    // hands and nobody needs 0.37 of the music.
                    divisions: kLevelSteps,
                    label: label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A line of the how-to, numbered so it reads as a sequence.
class MenuStep extends StatelessWidget {
  const MenuStep({required this.number, required this.text, super.key});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kMenuButtonGap * 0.7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: kMenuIconSize,
            height: kMenuIconSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kPlayFill,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: kMenuStatSize,
                fontWeight: FontWeight.w900,
                color: kMenuButtonInk,
              ),
            ),
          ),
          const SizedBox(width: kMenuButtonGap),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: kMenuTaglineSize,
                height: 1.35,
                color: kUiInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
