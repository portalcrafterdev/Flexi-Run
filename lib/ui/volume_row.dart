import 'package:flutter/material.dart';

import '../core/constants.dart';

/// One volume: a tinted strip with a coloured icon, its name, and a bar.
///
/// A bar rather than a switch, because off is just the bottom of it. One
/// control instead of two, and a parent who wants the game quiet rather than
/// silent has somewhere to say so.
///
/// It was called MenuLevel, from before the game had difficulty levels. Two
/// unrelated things called Level in one UI folder is a trap, and this is the
/// one that is not a level.
class VolumeRow extends StatelessWidget {
  const VolumeRow({
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
                    // Coarse steps. A continuous bar is fiddly for small hands
                    // and nobody needs 0.37 of the music.
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
