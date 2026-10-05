import 'package:flutter/material.dart';

/// One line of coach-mark text, in a panel beside the hole, typed out.
class TutorialCaption extends StatelessWidget {
  const TutorialCaption({
    required this.text,
    required this.hole,
    required this.screen,
    this.onSkip,
    this.onTap,
    super.key,
  });

  final String text;
  final Rect hole;
  final Size screen;
  /// Ends the whole sequence. Without it, a step whose target never arrives is
  /// a screen with every control blocked and no way off it.
  final VoidCallback? onSkip;

  /// What a tap on the panel itself means - carry on, or a refusal.
  ///
  /// The panel used to ignore pointers so that a tap could fall through to the
  /// scrim underneath. It cannot now, because the skip has to be pressable and
  /// a coloured box absorbs the tap whatever sits behind it. So the panel is
  /// given the meaning rather than made to disappear.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final above = hole.top;
    final below = screen.height - hole.bottom;
    final fits = kCaptionReserve;

    // Below a top target, above a bottom one. When neither side has the room -
    // a target taller than the screen has to spare - fall back to beside it,
    // on whichever side is clearer. Without that the panel is positioned off
    // an edge and is simply invisible, which reads as a broken tutorial.
    if (below >= fits || above >= fits) {
      final goBelow = below >= above;
      return Positioned(
        left: 0,
        right: 0,
        top: goBelow ? hole.bottom + kCaptionGap : null,
        bottom: goBelow ? null : screen.height - hole.top + kCaptionGap,
        // Align, because a Positioned with both left and right hands its child
        // TIGHT constraints - which force the panel to the full width whatever
        // maxWidth it was given. Only inside an Align does the ConstrainedBox
        // below actually bite. This is the usual reason a cap "does nothing".
        child: Align(
          alignment: goBelow ? Alignment.topCenter : Alignment.bottomCenter,
          child: _panel(context),
        ),
      );
    }

    final toLeft = hole.left >= screen.width - hole.right;
    return Positioned(
      left: toLeft ? 0 : hole.right + kCaptionGap,
      right: toLeft ? screen.width - hole.left + kCaptionGap : 0,
      top: 0,
      bottom: 0,
      child: Align(
        alignment: toLeft ? Alignment.centerRight : Alignment.centerLeft,
        child: _panel(context),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    // Capped by measure rather than by screen width: prose is bounded by how
    // far the eye travels back to find the next line, so the cap stays well
    // short of the screen however wide the screen gets.
    final width = screen.width;
    final cap = width < kCaptionCompactW
        ? kCaptionCapCompact
        : width < kCaptionMediumW
        ? kCaptionCapMedium
        : kCaptionCapExpanded;

    return Padding(
      padding: const EdgeInsets.all(kCaptionGap),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kCaptionPadX,
              vertical: kCaptionPadY,
            ),
            decoration: BoxDecoration(
              color: kCaptionFill,
              borderRadius: BorderRadius.circular(kCaptionRadius),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: kCaptionShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            // Beside the line rather than under it, so the panel is no taller
            // for having a way out of the sequence in it. The placement above
            // reserves a fixed band, and a panel that outgrew it would be laid
            // over the very thing it is pointing at.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(child: TypedText(text: text)),
                if (onSkip != null) ...<Widget>[
                  const SizedBox(width: kCaptionPadX),
                  _SkipChip(onPressed: onSkip!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The way out. Deliberately quiet: it is there for an adult helping out, and
/// for the case where a step cannot be satisfied at all - not as a choice being
/// offered to a six year old.
class _SkipChip extends StatelessWidget {
  const _SkipChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: kSkipLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: kSkipHeight,
          padding: const EdgeInsets.symmetric(horizontal: kSkipPadX),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kSkipFill,
            borderRadius: BorderRadius.circular(kSkipHeight / 2),
          ),
          child: const Text(
            kSkipLabel,
            style: TextStyle(
              fontSize: kSkipSize,
              fontWeight: FontWeight.w800,
              color: kSkipInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reveals [text] a grapheme at a time, without the box ever changing size.
class TypedText extends StatefulWidget {
  const TypedText({required this.text, super.key});

  final String text;

  @override
  State<TypedText> createState() => _TypedTextState();
}

class _TypedTextState extends State<TypedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));

  /// Split by grapheme cluster, not code unit: splitting by code unit cuts an
  /// accent off the letter it belongs to and a surrogate pair down the middle.
  late List<String> _glyphs = widget.text.characters.toList();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypedText old) {
    super.didUpdateWidget(old);
    // Only when the line itself changes. The overlay rebuilds on every refused
    // tap and every look for a target that was not laid out yet - a refusal
    // should replay the hand, but must not snatch back a sentence somebody is
    // halfway through reading.
    if (widget.text == old.text) return;
    _glyphs = widget.text.characters.toList();
    _start();
  }

  void _start() {
    // A long caption types FASTER rather than taking proportionally longer: a
    // coach mark stands between the player and the app, and must not make them
    // wait to be allowed to read a sentence.
    final ms = (_glyphs.length * kTypeMsPerGlyph).clamp(0, kTypeMaxMs).toInt();
    _run
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final shown = still ? _glyphs.length : (_run.value * _glyphs.length).ceil();

    // The whole line is laid out from the first frame and the tail painted
    // transparent, rather than left out. Three reasons, all of which bite: a
    // box that grows to fit moves every frame and drags the eye off the thing
    // being pointed at; wrapping settles once on the full string so no word
    // jumps lines mid-reveal; and find.text still finds the caption while it
    // types, because the span's plain text is the whole line throughout.
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(text: _glyphs.take(shown).join()),
          TextSpan(
            text: _glyphs.skip(shown).join(),
            style: const TextStyle(color: Color(0x00000000)),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: kCaptionSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: kCaptionInk,
      ),
    );
  }
}

const kCaptionGap = 12.0;
const kCaptionPadX = 14.0;
const kCaptionPadY = 10.0;
const kCaptionRadius = 16.0;
const kCaptionSize = 15.0;
const kCaptionFill = Color(0xFFFFFDF5);
const kCaptionInk = Color(0xFF46564E);
const kCaptionShadow = Color(0x59102A18);

/// Room a caption needs above or below the hole before it is placed there.
const kCaptionReserve = 86.0;

/// Width caps, by how wide the screen is - not fractions of it.
const kCaptionCompactW = 420.0;
const kCaptionMediumW = 720.0;
const kCaptionCapCompact = 300.0;
const kCaptionCapMedium = 360.0;
const kCaptionCapExpanded = 420.0;

/// Short, and also what a test looks for.
const kSkipLabel = 'Skip';
const kSkipHeight = 36.0;
const kSkipPadX = 14.0;
const kSkipSize = 13.0;
const kSkipFill = Color(0xFFE8EFE9);
const kSkipInk = Color(0xFF6B7D73);

const kTypeMsPerGlyph = 20;
const kTypeMaxMs = 900;
