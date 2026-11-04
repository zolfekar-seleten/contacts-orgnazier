import 'package:flutter/material.dart';

/// How national-format numbers (no `+` / country code) are interpreted.
sealed class RegionPreference {
  const RegionPreference();

  /// Use the region of the device locale.
  static const device = DeviceRegion();

  /// Don't interpret national numbers; they go to Unknown.
  static const none = NoRegion();

  String get storageValue => switch (this) {
    DeviceRegion() => 'device',
    NoRegion() => 'none',
    ManualRegion(:final isoCode) => isoCode,
  };

  static RegionPreference fromStorage(String? value) => switch (value) {
    null || 'device' => device,
    'none' => none,
    final iso => ManualRegion(iso),
  };
}

final class DeviceRegion extends RegionPreference {
  const DeviceRegion();
}

final class NoRegion extends RegionPreference {
  const NoRegion();
}

final class ManualRegion extends RegionPreference {
  const ManualRegion(this.isoCode);
  final String isoCode;

  @override
  bool operator ==(Object other) =>
      other is ManualRegion && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.region = RegionPreference.device,
  });

  final ThemeMode themeMode;
  final RegionPreference region;

  AppSettings copyWith({ThemeMode? themeMode, RegionPreference? region}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        region: region ?? this.region,
      );
}
