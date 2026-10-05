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
    this.top,
    this.ink = kMenuButtonInk,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color edge;

  /// The lit top of the moulding. Falls back to lightening [fill], which is
  /// what every slab did before the palette gained hand-picked top stops -
  /// lerping toward white desaturates, so a slab given only a fill still looks
  /// right, just flatter than one given both.
  final Color? top;

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
                    // Cast onto the meadow, so the slab sits above the scene
                    // rather than being printed on it.
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: kMenuShadow,
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
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
                  top: widget.top,
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
    this.top,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color? top;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final lit = top ?? Color.lerp(fill, Colors.white, kSlabSheen)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Lit from the top like everything else in the game. Three stops, not
        // two: the body holds most of the face and the last stop darkens only
        // the bottom edge, which is what stops a tall slab looking like a
        // gradient swatch.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[lit, fill, Color.lerp(fill, kSlabShade, 0.22)!],
          stops: const <double>[0, 0.62, 1],
        ),
        borderRadius: BorderRadius.circular(kMenuButtonRadius),
      ),
      child: Stack(
        // Explicit, and load-bearing: an unpositioned child in a Stack aligns
        // to the top corner, so wrapping the label to add the gloss silently
        // lifted it off centre on every slab.
        alignment: Alignment.center,
        children: <Widget>[
          // The gloss. Sits just inside the edge and only across the top, so it
          // reads as light landing on a curved face rather than as a second
          // colour band.
          // Positioned.fill, not a Positioned with only a top: a fractional
          // height needs a bounded one to be a fraction of, and without the
          // fill it is asked to lay out against infinity.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                left: kSlabGlossInset,
                right: kSlabGlossInset,
                top: kSlabGlossInset * 0.5,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: kSlabGlossShare,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kSlabGloss,
                      borderRadius: BorderRadius.circular(kMenuButtonRadius),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: kMenuIconSize, color: ink),
              const SizedBox(width: kMenuButtonGap),
              // Flexible, so a long label shortens instead of overflowing the
              // slab. Labels are written to fit, but one of them naming a
              // platform service is not under this app's control.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kMenuButtonFontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: kMenuButtonSpacing,
                    color: ink,
                    // A hairline of the slab's own shadow under the letters,
                    // so white ink stays legible on the lit top stop.
                    shadows: const <Shadow>[
                      Shadow(
                        color: kSlabInkShadow,
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

// The flat rainbow title that used to live here is gone: the home screen sets
// the name as a proper logo now, outlined and shadowed, in ui/menu_logo.dart.

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
          child: const ColoredBox(color: kUiScrim, child: SizedBox.expand()),
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

// The volume row that used to live here is now ui/volume_row.dart, as
// VolumeRow. It was MenuLevel, from before the game had difficulty levels, and
// two unrelated things called Level in one folder is a trap.

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
