// Generates the app icon into the Android and iOS project folders.
//
// Run with: flutter test tool/generate_app_icon.dart
//
// It is a test rather than a plain script because the icon is drawn with
// dart:ui, and dart:ui needs a Flutter binding to rasterise anything. Nothing
// here asserts; it writes files.
//
// The drawing lives in lib/core/art_icon.dart, from the same palette and the
// same character code as the game, so the icon cannot drift away from what the
// app looks like when you open it.

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/art_icon.dart';
import 'package:flexirun/core/constants.dart';

/// Android density buckets, as multiples of mdpi.
const _densities = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// The legacy launcher tile is 48dp.
const _legacyDp = 48.0;

const _androidRes = 'android/app/src/main/res';
const _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// Every size iOS asks for, keyed by the filename in Contents.json.
const _iosSizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const _adaptiveXml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';

typedef IconPainter = void Function(Canvas canvas, Size size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> write(String path, int pixels, IconPainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, Size(pixels.toDouble(), pixels.toDouble()));
    final picture = recorder.endRecording();
    final image = await picture.toImage(pixels, pixels);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  }

  test('write the launcher icons', () async {
    for (final entry in _densities.entries) {
      final dir = '$_androidRes/mipmap-${entry.key}';

      // The old square tile, for launchers that predate adaptive icons. It
      // rounds its own corners, because nothing else will.
      final legacy = (_legacyDp * entry.value).round();
      await write(
        '$dir/ic_launcher.png',
        legacy,
        (canvas, size) =>
            paintIcon(canvas, size, corner: size.width * kIconCorner),
      );

      // The adaptive pair. Square and full bleed: the launcher masks them to
      // whatever shape the phone uses, and anything outside the middle 72dp of
      // the 108 may be cropped away - which is why the runner is drawn smaller
      // on this one than on the tile above.
      final adaptive = (kIconAdaptiveDp * entry.value).round();
      await write('$dir/ic_launcher_background.png', adaptive, paintIconScene);
      await write(
        '$dir/ic_launcher_foreground.png',
        adaptive,
        (canvas, size) => paintIconRunner(
          canvas,
          size,
          bodyWidth: kIconRunnerWidthAdaptive,
          // Centred on this layer rather than standing on the hill: the
          // launcher masks it to a circle and crops the rest.
          centreY: 0.5,
          shadow: false,
        ),
      );
    }

    File('$_androidRes/mipmap-anydpi-v26/ic_launcher.xml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(_adaptiveXml.trimLeft());

    // iOS masks its own corners and wants the art edge to edge, so no rounding
    // here. Opaque everywhere: the store rejects an icon you can see through.
    for (final entry in _iosSizes.entries) {
      await write('$_iosIcons/${entry.key}', entry.value, paintIcon);
    }
  });
}
