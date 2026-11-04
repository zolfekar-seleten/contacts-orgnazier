import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _regionKey = 'default_region';

  AppSettings load() => AppSettings(
    themeMode:
        ThemeMode.values.asNameMap()[_prefs.getString(_themeKey)] ??
        ThemeMode.system,
    region: RegionPreference.fromStorage(_prefs.getString(_regionKey)),
  );

  Future<void> save(AppSettings settings) => Future.wait([
    _prefs.setString(_themeKey, settings.themeMode.name),
    _prefs.setString(_regionKey, settings.region.storageValue),
  ]);
}
