import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../countries/domain/country.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Region from the device locale (e.g. `AE` for `en-AE`), if it is a region
/// libphonenumber knows about.
final deviceRegionProvider = Provider<String?>((ref) {
  final code = PlatformDispatcher.instance.locale.countryCode;
  return Country.fromIso(code)?.isoCode;
});

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setRegion(RegionPreference region) =>
      _update(state.copyWith(region: region));

  void _update(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider.select((s) => s.themeMode)),
);

/// The region used to interpret national-format numbers, or null when the
/// user opted out or the device region is unknown.
final effectiveRegionProvider = Provider<String?>((ref) {
  final pref = ref.watch(settingsProvider.select((s) => s.region));
  return switch (pref) {
    DeviceRegion() => ref.watch(deviceRegionProvider),
    NoRegion() => null,
    ManualRegion(:final isoCode) => Country.fromIso(isoCode)?.isoCode,
  };
});
