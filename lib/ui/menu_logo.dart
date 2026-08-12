import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/shape_kind.dart';
import 'shape_glyph.dart';

/// The game's name, set straight onto the sky.
///
/// It used to live in a cream card with a gold rim. That is the shape of a
/// heading on a form, and it fought the scene behind it: a box drawn over a
/// meadow is a hole in the meadow. A game's name is a logo, and what makes it
/// read as one is weight rather than a frame - a dark outline and a shadow
/// under it, so the letters sit on the sky instead of floating in front of it.
///
/// Each letter takes its own colour, rides a shallow wave and leans against
/// its neighbours, so the name bounces along the way the runner does.
class GameLogo extends StatelessWidget {
  const GameLogo(this.text, {this.fontSize = kLogoSize, super.key});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    var colour = 0;
    return Semantics(
      label: text,
      header: true,
      child: ExcludeSemantics(
        // The wave lifts letters out of the row's own box. Transform does not
        // affect layout, so the room has to be asked for here or a tight
        // parent will crop the tops off.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: fontSize * kLogoBounce),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final (i, letter) in text.split('').indexed)
                // Spaces hold their slot but take no colour, so the second word
                // does not restart the sequence.
                letter == ' '
                    ? _letter(letter, i, const Color(0x00000000))
                    : _letter(
                        letter,
                        i,
                        kTitleLetterColors[colour++ % kTitleLetterColors.length],
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _letter(String glyph, int index, Color colour) {
    final lift = sin(index * kLogoWaveStep) * fontSize * kLogoBounce;
    final tilt = index.isEven ? kLogoTilt : -kLogoTilt;
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          children: <Widget>[
            // Outline and shadow underneath, the fill exactly on top. Two
            // passes of the same glyph: a stroke and a fill cannot be asked
            // for in one TextStyle.
            Text(glyph, style: _outlineStyle),
            Text(glyph, style: _base.copyWith(color: colour)),
          ],
        ),
      ),
    );
  }

  TextStyle get _base => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: kLogoSpacing,
    height: 1,
  );

  TextStyle get _outlineStyle => _base.copyWith(
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fontSize * kLogoOutlineWidth
      // Round, or the outline grows spikes off every corner of a W or an X.
      ..strokeJoin = StrokeJoin.round
      ..color = kLogoOutline,
    shadows: <Shadow>[
      Shadow(
        color: kLogoShadow,
        offset: Offset(0, fontSize * kLogoShadowDrop),
        blurRadius: fontSize * kLogoShadowBlur,
      ),
    ],
  );
}

/// What the game is, on a translucent lozenge under the name.
///
/// The lozenge earns its place: the sentence sits over sky the clouds drift
/// through, and plain text there is legible right up until one arrives.
class TaglinePill extends StatelessWidget {
  const TaglinePill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kTaglinePadX,
        vertical: kTaglinePadY,
      ),
      decoration: BoxDecoration(
        color: kTaglinePill,
        borderRadius: BorderRadius.circular(kTaglinePillRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: kMenuShadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The three shapes lead the sentence rather than sitting on a line of
          // their own: they are what "the shape" means, so they belong in it.
          for (final kind in ShapeKind.values)
            Padding(
              padding: const EdgeInsets.only(right: kTaglineGlyphGap),
              child: ShapeGlyph(
                kind: kind,
                color:
                    kTitleLetterColors[kind.index % kTitleLetterColors.length],
                size: kTaglineGlyph,
              ),
            ),
          const SizedBox(width: kTaglineGlyphGap),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: kMenuTaglineSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: kMenuStat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
