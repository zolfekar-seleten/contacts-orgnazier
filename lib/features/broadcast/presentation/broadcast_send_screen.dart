import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../domain/broadcast.dart';
import 'broadcast_providers.dart';

/// Walks through recipients one at a time. Each tap opens WhatsApp or
/// Messages with that person's message prefilled; the user sends it there.
class BroadcastSendScreen extends ConsumerWidget {
  const BroadcastSendScreen({super.key});

  void _finish(BuildContext context, WidgetRef ref) {
    ref.read(broadcastProvider.notifier).finish();
    ref.read(selectionProvider.notifier).exit();
    // Back to the contact list the selection started from.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(broadcastProvider.notifier);
    final outcome = await controller.openCurrent();
    if (!context.mounted) return;
    switch (outcome) {
      case OpenOutcome.opened:
        break;
      case OpenOutcome.whatsAppMissing:
        final web = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const WhatsAppIcon(size: 36),
            title: const Text('WhatsApp isn’t available'),
            content: const Text(
              'WhatsApp doesn’t seem to be installed. Continue with WhatsApp '
              'Web in your browser for this recipient?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open WhatsApp Web'),
              ),
            ],
          ),
        );
        if (web == true) await controller.openCurrent(viaWeb: true);
      case OpenOutcome.unsupported:
        _snack(context, 'This device can’t send text messages.');
      case OpenOutcome.failed:
        _snack(context, 'Couldn’t open the app for this number.');
    }
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(broadcastProvider);
    if (session == null) return const Scaffold();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = contentPadding(context);
    final handled =
        session.items.length - session.count(DeliveryStatus.pending);
    final appName = session.channel == BroadcastChannel.whatsApp
        ? 'WhatsApp'
        : 'Messages';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(broadcastProvider.notifier).finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Send via ${session.channel.label}'),
          actions: [
            TextButton(
              key: const Key('broadcast-done'),
              onPressed: () => _finish(context, ref),
              child: const Text('Done'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: padding.copyWith(top: 4, bottom: 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: session.items.isEmpty
                          ? 1
                          : handled / session.items.length,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$handled of ${session.items.length}',
                  key: const Key('broadcast-progress'),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (session.current case final item?)
              _CurrentCard(
                item: item,
                channel: session.channel,
                appName: appName,
                onOpen: () => _open(context, ref),
                onSkip: ref.read(broadcastProvider.notifier).skipCurrent,
              )
            else
              _DoneCard(
                opened: session.count(DeliveryStatus.opened),
                skipped:
                    session.count(DeliveryStatus.skipped) +
                    session.count(DeliveryStatus.failed),
                appName: appName,
                onFinish: () => _finish(context, ref),
              ),
            const SectionHeader('Recipients'),
            for (var i = 0; i < session.items.length; i++)
              GroupedListItem(
                index: i,
                count: session.items.length,
                child: _RecipientRow(
                  item: session.items[i],
                  isCurrent: i == session.index,
                  onTap: () => ref.read(broadcastProvider.notifier).jumpTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({
    required this.item,
    required this.channel,
    required this.appName,
    required this.onOpen,
    required this.onSkip,
  });

  final BroadcastItem item;
  final BroadcastChannel channel;
  final String appName;
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final whatsApp = channel == BroadcastChannel.whatsApp;
    final country = item.phone.country;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppColors.softShadow(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ContactAvatar(contact: item.contact, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.contact.displayName,
                      key: const Key('current-recipient'),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${country?.flag ?? ''} ${item.phone.e164 ?? item.phone.raw}'
                          .trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              item.message,
              key: const Key('current-message'),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('open-current'),
            style: whatsApp
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.whatsApp,
                    foregroundColor: const Color(0xFF06331B),
                  )
                : null,
            onPressed: onOpen,
            icon: whatsApp
                ? const WhatsAppIcon(size: 22, color: Color(0xFF06331B))
                : const Icon(Icons.sms_rounded),
            label: Text('Open $appName'),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('skip-current'),
            onPressed: onSkip,
            child: const Text('Skip this person'),
          ),
          Text(
            '$appName opens with the message filled in. Tap send there, then '
            'come back for the next person.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.opened,
    required this.skipped,
    required this.appName,
    required this.onFinish,
  });

  final int opened;
  final int skipped;
  final String appName;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.hero(theme.brightness),
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_alt_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 10),
          Text(
            'All done',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            // Opening a chat is not the same as sending; say only what we know.
            '$opened ${opened == 1 ? 'chat' : 'chats'} opened in $appName'
            '${skipped > 0 ? ', $skipped skipped' : ''}. Messages are only '
            'sent when you tapped send there.',
            key: const Key('broadcast-summary'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
            ),
            onPressed: onFinish,
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.item,
    required this.isCurrent,
    required this.onTap,
  });

  final BroadcastItem item;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, label, color) = switch (item.status) {
      DeliveryStatus.pending => (
        Icons.schedule_rounded,
        isCurrent ? 'Up next' : 'Waiting',
        scheme.onSurfaceVariant,
      ),
      DeliveryStatus.opened => (
        Icons.check_circle_rounded,
        'Opened',
        const Color(0xFF16A34A),
      ),
      DeliveryStatus.skipped => (
        Icons.remove_circle_outline_rounded,
        'Skipped',
        scheme.outline,
      ),
      DeliveryStatus.failed => (
        Icons.error_outline_rounded,
        'Couldn’t open',
        scheme.error,
      ),
    };
    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      selectedTileColor: scheme.secondary.withValues(alpha: 0.06),
      leading: ContactAvatar(contact: item.contact, size: 36),
      title: Text(
        item.contact.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
