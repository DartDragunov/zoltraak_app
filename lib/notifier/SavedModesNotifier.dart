import 'package:flutter/foundation.dart';
import 'package:zoltraak_app/db/DatabaseHelper.dart';
import 'package:zoltraak_app/model/SavedMode.dart';

class SavedModesNotifier extends ChangeNotifier {
  static final SavedModesNotifier _instance = SavedModesNotifier._internal();
  factory SavedModesNotifier() => _instance;
  SavedModesNotifier._internal();

  final List<SavedMode> _modes = [];
  List<SavedMode> get modes => List.unmodifiable(_modes);

  /// Loads all modes from the database. Call once at app start or screen init.
  Future<void> loadAll() async {
    final loaded = await DatabaseHelper().getAllModes();
    _modes
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Inserts or replaces a mode (matched by name). Persists to DB.
  Future<void> saveMode(SavedMode mode) async {
    final id = await DatabaseHelper().insertMode(mode);
    final withId = mode.copyWith(id: id);
    final idx = _modes.indexWhere((m) => m.name == mode.name);
    if (idx >= 0) {
      _modes[idx] = withId;
    } else {
      _modes.add(withId);
    }
    notifyListeners();
  }

  /// Deletes the mode at [index] from the list and the database.
  Future<void> deleteMode(int index) async {
    if (index < 0 || index >= _modes.length) return;
    final mode = _modes[index];
    if (mode.id != null) await DatabaseHelper().deleteMode(mode.id!);
    _modes.removeAt(index);
    notifyListeners();
  }
}
