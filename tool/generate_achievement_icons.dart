// Generates the twelve achievement icons and the icon mappings CSV.
//
// Run with: flutter test tool/generate_achievement_icons.dart
//
// A test rather than a plain script for the same reason the app icon
// generator is one: the icons are drawn with dart:ui, and dart:ui needs a
// Flutter binding to rasterise anything. Nothing here asserts; it writes
// files into tool/play_games/, ready to be zipped and imported.
//
// The drawing lives in tool/award_art.dart.

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'award_art.dart';

/// What Play Console asks for. App Store Connect takes the same file.
const _pixels = 512;

const _outDir = 'tool/play_games';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> writeIcon(String path, AwardPainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, const Size(_pixels * 1.0, _pixels * 1.0));
    final picture = recorder.endRecording();
    final image = await picture.toImage(_pixels, _pixels);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  }

  /// `First Run` becomes `first_run.png`, which is also what the mappings CSV
  /// points at - both derived from the one name so they cannot drift.
  String fileFor(String name) =>
      '${name.toLowerCase().replaceAll(' ', '_')}.png';

  test('writes the achievement icons and their mappings', () async {
    final rows = <String>[];

    for (final entry in awards.entries) {
      final file = fileFor(entry.key);
      await writeIcon('$_outDir/$file', entry.value);
      rows.add('${entry.key},$file');
    }

    // Same shape as AchievementsMetadata.csv: no header row, and no comma may
    // appear inside a field.
    File('$_outDir/AchievementsIconsMappings.csv')
        .writeAsStringSync('${rows.join('\n')}\n');

    // The leaderboards are uploaded one at a time in the console's own form,
    // so they get files and no mappings row - and must stay out of the import
    // zip, which accepts only the achievements.
    for (final entry in boards.entries) {
      await writeIcon('$_outDir/${fileFor(entry.key)}', entry.value);
    }

    // ignore: avoid_print
    print(
      'Wrote ${rows.length} achievement icons and '
      '${boards.length} leaderboard icons to $_outDir',
    );
  });
}
