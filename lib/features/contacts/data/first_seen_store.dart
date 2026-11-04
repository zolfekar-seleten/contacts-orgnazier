import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the app first saw each contact, since iOS doesn't expose
/// when a contact was created. Stored on the device only.
class FirstSeenStore {
  const FirstSeenStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'contact_first_seen';

  /// Records [ids] not seen before at [now] and forgets deleted ones.
  /// On the very first run every contact is recorded as 0, so only contacts
  /// added after installing the app count as recently added.
  Map<String, int> sync(Iterable<String> ids, DateTime now) {
    final raw = _prefs.getString(_key);
    final firstRun = raw == null;
    final stored = firstRun
        ? <String, int>{}
        : (jsonDecode(raw) as Map<String, dynamic>).cast<String, int>();
    final stamp = firstRun ? 0 : now.millisecondsSinceEpoch;
    final next = {for (final id in ids) id: stored[id] ?? stamp};
    if (firstRun || !_sameKeys(stored, next)) {
      _prefs.setString(_key, jsonEncode(next));
    }
    return next;
  }

  static bool _sameKeys(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.keys.every(b.containsKey);
}
