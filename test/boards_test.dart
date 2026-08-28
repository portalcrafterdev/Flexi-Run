import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/core/boards.dart';
import 'package:flexirun/core/level.dart';

// The score leaderboards. One per level, because the levels are not
// comparable - and only the ones that actually exist in a store's console are
// ever written to.

void main() {
  group('boards', () {
    test('there is exactly one board per level', () {
      expect(Board.values.map((b) => b.level).toSet(), Level.values.toSet());
      expect(Board.values, hasLength(Level.values.length));
    });

    test('every level maps to its own board, and only when it is ready', () {
      // All three are live now, so the isNull branch below does not currently
      // run. It is kept for the next board added - a coins board, or a fourth
      // level - which starts with an empty id, and whose failure would be a
      // submission to '' on every run: silent, and indistinguishable from the
      // feature being broken.
      for (final board in Board.values) {
        final found = Board.forLevel(board.level);
        if (board.isReady) {
          expect(found, board, reason: '${board.name} should be usable');
        } else {
          expect(found, isNull, reason: '${board.name} has no id yet');
        }
      }
    });

    test('all three levels are wired up', () {
      for (final level in Level.values) {
        final board = Board.forLevel(level);
        expect(board, isNotNull, reason: 'no board for ${level.name}');
        expect(board!.androidId, isNotEmpty, reason: '${level.name} play id');
        expect(board.iosId, isNotEmpty, reason: '${level.name} game center id');
      }
    });

    test('the Play id matches the console export', () {
      // Same guard the achievements have: the id in Dart is a hand copy of
      // what Play Console handed back, and the two drifting apart would submit
      // scores into nowhere while looking perfectly fine in a diff.
      final xml = File(
        'android/app/src/main/res/values/games-ids.xml',
      ).readAsStringSync();

      for (final board in Board.values.where((b) => b.isReady)) {
        final match = RegExp(
          '<string name="leaderboard_${board.iosId}"[^>]*>([^<]+)</string>',
        ).firstMatch(xml);
        expect(
          match?.group(1),
          board.androidId,
          reason: '${board.name} does not match games-ids.xml',
        );
      }
    });

    test('no id is shared between two boards', () {
      final ready = Board.values.where((b) => b.isReady).toList();
      expect(
        ready.map((b) => b.androidId).toSet(),
        hasLength(ready.length),
        reason: 'a duplicated id would file scores under the wrong level',
      );
      // The Game Center ids are all set from the start, so all of them count.
      expect(
        Board.values.map((b) => b.iosId).toSet(),
        hasLength(Board.values.length),
      );
    });

    test('every board has an icon to upload', () {
      for (final board in Board.values) {
        expect(
          File('tool/play_games/${board.iosId}.png').existsSync(),
          isTrue,
          reason: 'missing icon for ${board.name}',
        );
      }
    });
  });
}
