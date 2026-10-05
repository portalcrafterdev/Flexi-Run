import 'package:shared_preferences/shared_preferences.dart';

/// Whether a tutorial sequence has been seen, behind an interface.
///
/// Not for neatness. [SharedPreferences.getInstance] never completes under a
/// widget test binding that has not been given mock values - so a controller
/// that reached for it directly would turn "has this been seen?" into a way to
/// freeze the screen it is about to teach.
abstract class TutorialStore {
  Future<bool> hasSeen(String flag);
  Future<void> markSeen(String flag);
  Future<void> clear(String flag);
}

/// The real one.
class PrefsTutorialStore implements TutorialStore {
  const PrefsTutorialStore();

  @override
  Future<bool> hasSeen(String flag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(flag) ?? false;
    } catch (_) {
      // Storage unavailable. Showing the tutorial again is the kinder failure:
      // the alternative is a first-time player who never gets taught.
      return false;
    }
  }

  @override
  Future<void> markSeen(String flag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(flag, true);
    } catch (_) {
      // It will run again next launch. Not worth interrupting anyone over.
    }
  }

  @override
  Future<void> clear(String flag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(flag);
    } catch (_) {}
  }
}

/// For tests, and for any sequence that should not outlive the session.
class MemoryTutorialStore implements TutorialStore {
  MemoryTutorialStore([Set<String>? seen]) : _seen = seen ?? <String>{};

  final Set<String> _seen;

  @override
  Future<bool> hasSeen(String flag) async => _seen.contains(flag);

  @override
  Future<void> markSeen(String flag) async => _seen.add(flag);

  @override
  Future<void> clear(String flag) async => _seen.remove(flag);
}
