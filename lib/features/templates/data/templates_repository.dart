import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/saved_template.dart';

/// Saved templates, kept on the device in shared preferences.
class TemplatesRepository {
  const TemplatesRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'saved_templates';

  /// The starter templates until the user has saved a list of their own.
  List<SavedTemplate> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return SavedTemplate.starters;
    return [
      for (final item in jsonDecode(raw) as List<dynamic>)
        SavedTemplate.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> save(List<SavedTemplate> templates) => _prefs.setString(
    _key,
    jsonEncode([for (final t in templates) t.toJson()]),
  );
}
