import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/clock.dart';
import '../../crm/presentation/crm_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/cloud_service.dart';
import '../data/icloud_files.dart';

/// The iCloud container; a folder stand-in in tests.
final cloudFilesProvider = Provider<CloudFiles>(
  (ref) => const ChannelCloudFiles(),
);

final cloudServiceProvider = Provider(
  (ref) => CloudService(
    db: ref.watch(crmDatabaseProvider),
    files: ref.watch(cloudFilesProvider),
    attachments: ref.watch(attachmentStoreProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    tempDir: getTemporaryDirectory,
    clock: ref.watch(clockProvider),
  ),
);

enum CloudTask { backup, sync, restore }

class CloudState {
  const CloudState({
    this.available,
    required this.backupEnabled,
    required this.syncEnabled,
    this.lastBackup,
    this.lastSync,
    this.busy,
    this.error,
  });

  /// Null until checked.
  final bool? available;
  final bool backupEnabled;
  final bool syncEnabled;
  final DateTime? lastBackup;
  final DateTime? lastSync;
  final CloudTask? busy;
  final String? error;

  CloudState copyWith({
    bool? available,
    bool? backupEnabled,
    bool? syncEnabled,
    DateTime? lastBackup,
    DateTime? lastSync,
    CloudTask? Function()? busy,
    String? Function()? error,
  }) => CloudState(
    available: available ?? this.available,
    backupEnabled: backupEnabled ?? this.backupEnabled,
    syncEnabled: syncEnabled ?? this.syncEnabled,
    lastBackup: lastBackup ?? this.lastBackup,
    lastSync: lastSync ?? this.lastSync,
    busy: busy == null ? this.busy : busy(),
    error: error == null ? this.error : error(),
  );
}

/// Runs backups and sync: on launch and on returning to the app (sync, then
/// the daily backup if due), shortly after local edits (sync), and when the
/// user asks. Nothing touches the database until iCloud is available.
class CloudController extends Notifier<CloudState> {
  StreamSubscription<void>? _changes;
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  var _applyingRemote = false;

  CloudService get _service => ref.read(cloudServiceProvider);

  @override
  CloudState build() {
    ref.onDispose(() {
      _changes?.cancel();
      _debounce?.cancel();
      _lifecycle?.dispose();
    });
    final prefs = ref.watch(sharedPreferencesProvider);
    int? ms(String key) => prefs.getInt(key);
    return CloudState(
      backupEnabled: prefs.getBool(CloudService.backupEnabledKey) ?? true,
      syncEnabled: prefs.getBool(CloudService.syncEnabledKey) ?? true,
      lastBackup: ms(
        'icloud_last_backup',
      )?.let(DateTime.fromMillisecondsSinceEpoch),
      lastSync: ms(
        'icloud_last_sync',
      )?.let(DateTime.fromMillisecondsSinceEpoch),
    );
  }

  /// Called once from the app shell.
  Future<void> start() async {
    _lifecycle ??= AppLifecycleListener(onResume: _auto);
    await _auto();
  }

  Future<void> _auto() async {
    final available = await ref.read(cloudFilesProvider).isAvailable();
    if (!ref.mounted) return;
    state = state.copyWith(available: available);
    if (!available) return;
    _watchLocalChanges();
    if (state.syncEnabled) await syncNow(quiet: true);
    if (state.backupEnabled && state.busy == null) {
      await _run(CloudTask.backup, () => _service.backupIfDue(), quiet: true);
    }
  }

  /// Sync about 20 seconds after the user changes something.
  void _watchLocalChanges() {
    if (_changes != null) return;
    final db = ref.read(crmDatabaseProvider);
    _changes = db.tableUpdates().listen((_) {
      if (_applyingRemote || !state.syncEnabled) return;
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(seconds: 20),
        () => syncNow(quiet: true),
      );
    });
  }

  Future<bool> backupNow() =>
      _run(CloudTask.backup, () => _service.backupNow());

  Future<bool> syncNow({bool quiet = false}) => _run(CloudTask.sync, () async {
    _applyingRemote = true;
    try {
      await _service.syncNow();
    } finally {
      // Let the table-update events from the merge pass first.
      await Future<void>.delayed(Duration.zero);
      _applyingRemote = false;
    }
  }, quiet: quiet);

  Future<bool> restore(String name) => _run(CloudTask.restore, () async {
    _applyingRemote = true;
    try {
      await _service.restore(name);
    } finally {
      await Future<void>.delayed(Duration.zero);
      _applyingRemote = false;
    }
  });

  Future<List<CloudFile>> backups() => _service.backups();

  Future<void> setBackupEnabled(bool on) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(CloudService.backupEnabledKey, on);
    state = state.copyWith(backupEnabled: on);
    if (on && state.available == true) {
      await _run(CloudTask.backup, () => _service.backupIfDue(), quiet: true);
    }
  }

  Future<void> setSyncEnabled(bool on) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(CloudService.syncEnabledKey, on);
    state = state.copyWith(syncEnabled: on);
    if (on && state.available == true) await syncNow(quiet: true);
  }

  /// Runs one task at a time; returns false if it failed or another task
  /// was running. Failures in background runs are kept out of the way.
  Future<bool> _run(
    CloudTask task,
    Future<void> Function() body, {
    bool quiet = false,
  }) async {
    if (state.busy != null) return false;
    state = state.copyWith(busy: () => task, error: () => null);
    try {
      await body();
      final s = _service;
      if (!ref.mounted) return true;
      state = state.copyWith(
        busy: () => null,
        lastBackup: s.lastBackup,
        lastSync: s.lastSync,
      );
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        busy: () => null,
        error: () => quiet ? null : '$e',
      );
      return false;
    }
  }
}

final cloudControllerProvider = NotifierProvider<CloudController, CloudState>(
  CloudController.new,
);

extension<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}
