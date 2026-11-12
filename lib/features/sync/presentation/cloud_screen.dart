import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../local_time/presentation/local_time_widgets.dart';
import '../data/icloud_files.dart';
import 'cloud_providers.dart';

/// iCloud backup (daily, restorable) and sync between the user's devices.
class CloudScreen extends ConsumerStatefulWidget {
  const CloudScreen({super.key});

  @override
  ConsumerState<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends ConsumerState<CloudScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh availability whenever the screen opens.
    Future.microtask(() => ref.read(cloudControllerProvider.notifier).start());
  }

  String _when(DateTime? t) {
    if (t == null) return 'Never';
    final l = MaterialLocalizations.of(context);
    return '${l.formatMediumDate(t)} at ${formatClock(context, t)}';
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _restore() async {
    final controller = ref.read(cloudControllerProvider.notifier);
    List<CloudFile> list;
    try {
      list = await controller.backups();
    } catch (e) {
      _snack('$e');
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<CloudFile>(
      context: context,
      useSafeArea: true,
      builder: (context) => _BackupList(backups: list),
    );
    if (picked == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Your leads, clients and activities on this device will be '
          'replaced with the backup from ${_when(picked.modified)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('restore-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await controller.restore(picked.name)) _snack('Backup restored.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudControllerProvider);
    final controller = ref.read(cloudControllerProvider.notifier);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    final iOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final ready = state.available == true;
    final busy = state.busy;

    return Scaffold(
      appBar: AppBar(title: const Text('iCloud')),
      body: ListView(
        padding: contentPadding(context).copyWith(bottom: 32),
        children: [
          _StatusCard(available: state.available, iOS: iOS, busy: busy),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                state.error!,
                key: const Key('cloud-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SectionHeader('Backup'),
          GroupedListItem(
            index: 0,
            count: 2,
            child: SwitchListTile(
              key: const Key('cloud-daily'),
              title: const Text('Back up every day'),
              subtitle: const Text('The last 14 backups are kept'),
              value: state.backupEnabled,
              onChanged: ready ? controller.setBackupEnabled : null,
            ),
          ),
          GroupedListItem(
            index: 1,
            count: 2,
            child: ListTile(
              title: const Text('Last backup'),
              subtitle: Text(_when(state.lastBackup)),
              trailing: busy == CloudTask.backup
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('cloud-backup-now'),
                  onPressed: !ready || busy != null
                      ? null
                      : () async {
                          if (await controller.backupNow()) {
                            _snack('Backed up to iCloud.');
                          }
                        },
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Back up now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('cloud-restore'),
                  onPressed: !ready || busy != null ? null : _restore,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Backups include your leads, clients, statuses, purchases, '
            'activities and their images. Find them in the Files app under '
            'iCloud Drive › Contacts Organizer.',
            style: muted,
          ),
          const SectionHeader('Sync'),
          GroupedListItem(
            index: 0,
            count: 2,
            child: SwitchListTile(
              key: const Key('cloud-sync'),
              title: const Text('Sync with my other devices'),
              subtitle: const Text('iPhone and iPad with the same Apple ID'),
              value: state.syncEnabled,
              onChanged: ready ? controller.setSyncEnabled : null,
            ),
          ),
          GroupedListItem(
            index: 1,
            count: 2,
            child: ListTile(
              title: const Text('Last synced'),
              subtitle: Text(_when(state.lastSync)),
              trailing: busy == CloudTask.sync
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      key: const Key('cloud-sync-now'),
                      onPressed: !ready || !state.syncEnabled || busy != null
                          ? null
                          : () async {
                              if (await controller.syncNow()) {
                                _snack('Synced.');
                              }
                            },
                      child: const Text('Sync now'),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Changes on each device are merged; when the same record was '
            'edited on two devices, the latest edit wins. Your phone’s '
            'contacts aren’t uploaded.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.available,
    required this.iOS,
    required this.busy,
  });

  final bool? available;
  final bool iOS;
  final CloudTask? busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message) = switch (available) {
      null => ('Checking iCloud…', ''),
      true => (
        switch (busy) {
          CloudTask.backup => 'Backing up…',
          CloudTask.sync => 'Syncing…',
          CloudTask.restore => 'Restoring…',
          null => 'iCloud is on',
        },
        'Your data is backed up to your Apple ID.',
      ),
      false when iOS => (
        'iCloud is off',
        'Sign in to iCloud in the Settings app and turn on iCloud Drive to '
            'back up and sync.',
      ),
      false => (
        'Available on iPhone',
        'iCloud backup and sync work on iPhone and iPad.',
      ),
    };
    return Container(
      key: const Key('cloud-status'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.hero(theme.brightness),
        borderRadius: BorderRadius.circular(AppTheme.radius + 6),
      ),
      child: Row(
        children: [
          if (busy != null)
            const SizedBox.square(
              dimension: 36,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            )
          else
            Icon(
              available == true
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 36,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({required this.backups});

  final List<CloudFile> backups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = MaterialLocalizations.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Choose a backup', style: theme.textTheme.titleMedium),
        ),
        if (backups.isEmpty) const ListTile(title: Text('No backups yet')),
        for (final b in backups)
          ListTile(
            key: ValueKey('backup-${b.name}'),
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              '${l.formatMediumDate(b.modified)} at '
              '${formatClock(context, b.modified)}',
            ),
            subtitle: Text(
              '${(b.size / 1024).ceil()} KB'
              '${b.downloaded ? '' : ' · in iCloud'}',
            ),
            onTap: () => Navigator.pop(context, b),
          ),
      ],
    );
  }
}
