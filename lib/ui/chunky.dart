import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';

/// An in-game control: a pale face lifted off the world by a soft shadow,
/// which shrinks under the finger.
///
/// Deliberately not the menu's lip-and-face slab. That reads as thickness at
/// slab size and opacity; small, round and translucent over a moving world it
/// renders as a second circle offset below the button, which looks like a
/// smudge. A blurred shadow gives the same lift without drawing a shape.
class ChunkyTile extends StatefulWidget {
  const ChunkyTile({
    required this.size,
    required this.onPressed,
    required this.child,
    this.face = kPadFace,
    this.ring,
    this.circle = false,
    this.semanticLabel,
    super.key,
  });

  final double size;

  /// Fires on press down, not release: a morph has to land the instant the
  /// finger touches, because the wall is already arriving.
  final VoidCallback onPressed;

  final Widget child;
  final Color face;

  /// Drawn around the face when set. Used to mark the shape currently worn.
  final Color? ring;
  final bool circle;
  final String? semanticLabel;

  @override
  State<ChunkyTile> createState() => _ChunkyTileState();
}

class _ChunkyTileState extends State<ChunkyTile> {
  bool _down = false;

  void _release() {
    if (_down) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.circle ? widget.size / 2 : kShapeButtonRadius;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _down = true);
          widget.onPressed();
        },
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: SizedBox(
          // The tap target never drops below the minimum, however small the
          // face is drawn. A shrunken button must not become a harder one to
          // hit: this is a game for six year olds.
          width: max(widget.size, kMinTapTarget),
          height: max(widget.size, kMinTapTarget),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              scale: _down ? kPadPressScale : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.face,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: widget.ring ?? kPadEdge,
                    width: widget.ring == null
                        ? kPadEdgeWidth
                        : kActiveRingWidth,
                  ),
                  boxShadow: <BoxShadow>[
                    const BoxShadow(
                      color: kPadShadow,
                      blurRadius: kPadShadowBlur,
                      offset: Offset(0, kPadShadowDrop),
                    ),
                    // The selected control glows rather than only being
                    // outlined, so it is obvious at a glance which it is.
                    if (widget.ring != null)
                      const BoxShadow(
                        color: kPadActiveGlow,
                        blurRadius: kPadGlowBlur,
                      ),
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text with a heavy outline, drawn twice: the stroke behind, the fill on top.
///
/// This is how a game HUD stays readable over anything without sitting in a
/// box. A card solves the same problem but takes up room and covers the world;
/// an outline costs nothing and is what the reference art does.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    required this.size,
    this.fill = kHudInk,
    this.outline = kHudOutline,
    super.key,
  });

  final String text;
  final double size;
  final Color fill;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      height: 1.1,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Stack(
      children: <Widget>[
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = kHudOutlineWidth
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(text, style: base.copyWith(color: fill)),
      ],
    );
  }
}

/// An icon with the same outline treatment: a fatter copy behind a smaller one.
class OutlinedGlyph extends StatelessWidget {
  const OutlinedGlyph({
    required this.icon,
    required this.size,
    required this.fill,
    this.outline = kHudOutline,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color fill;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + kHudOutlineWidth,
      height: size + kHudOutlineWidth,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon, size: size + kHudOutlineWidth, color: outline),
          Icon(icon, size: size, color: fill),
        ],
      ),
    );
  }
}

/// A cream card for anything on the HUD that is read rather than pressed.
class HudPill extends StatelessWidget {
  const HudPill({required this.child, this.color = kGameCard, super.key});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kHudPillPadX,
        vertical: kHudPillPadY,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(kHudPillRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: kPadShadow,
            blurRadius: kPadShadowBlur,
            offset: Offset(0, kPadShadowDrop),
          ),
        ],
      ),
      child: child,
    );
  }
}
