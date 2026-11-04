import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../contacts/domain/app_contact.dart';
import '../../local_time/domain/local_time.dart';
import '../../templates/presentation/template_widgets.dart';
import '../../templates/presentation/templates_providers.dart';
import '../domain/broadcast.dart';
import '../domain/message_template.dart';
import 'broadcast_providers.dart';
import 'broadcast_send_screen.dart';

/// Write one message for many contacts, personalised with name placeholders.
class BroadcastComposeScreen extends ConsumerStatefulWidget {
  const BroadcastComposeScreen({super.key});

  @override
  ConsumerState<BroadcastComposeScreen> createState() =>
      _BroadcastComposeScreenState();
}

class _BroadcastComposeScreenState
    extends ConsumerState<BroadcastComposeScreen> {
  // Ephemeral form state: the text being typed and which preview is shown.
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _previewIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _previewIndex.dispose();
    super.dispose();
  }

  /// Inserts [text] at the cursor (or replaces the selection).
  void _insert(String text) {
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final before = value.text.substring(0, selection.start);
    final needsSpace = before.isNotEmpty && !RegExp(r'[\s(]$').hasMatch(before);
    final insert = needsSpace ? ' $text' : text;
    _controller.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, insert),
      selection: TextSelection.collapsed(
        offset: selection.start + insert.length,
      ),
    );
    _focus.requestFocus();
  }

  void _applyTemplate(String template) {
    _controller.value = TextEditingValue(
      text: template,
      selection: TextSelection.collapsed(offset: template.length),
    );
    _focus.requestFocus();
  }

  void _review(List<AppContact> contacts, BroadcastDraft draft) {
    final plan = planBroadcast(
      contacts,
      channel: draft.channel,
      template: _controller.text,
      countryKey: draft.countryKey,
    );
    ref.read(broadcastProvider.notifier).start(draft.channel, plan.items);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BroadcastSendScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = ref.watch(broadcastDraftProvider);
    final contacts = ref.watch(draftContactsProvider);
    final reachable = [
      for (final c in contacts)
        if (pickBroadcastPhone(
              c,
              draft.channel,
              countryKey: draft.countryKey,
            ) !=
            null)
          c,
    ];
    final skipped = contacts.length - reachable.length;
    final padding = contentPadding(context);
    final templates = ref.watch(savedTemplatesProvider);
    final now = ref.watch(minuteTickProvider);
    final lateNight = reachable.where((c) {
      final phone = pickBroadcastPhone(
        c,
        draft.channel,
        countryKey: draft.countryKey,
      );
      return localTimeIn(phone?.classification.isoCode, now)?.isLateNight ??
          false;
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: ListView(
        padding: padding.copyWith(top: 4, bottom: 24),
        children: [
          _Label('To · ${contacts.length}'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: contacts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = contacts[i];
                return InputChip(
                  key: ValueKey('recipient-${c.id}'),
                  avatar: ContactAvatar(contact: c, size: 24),
                  label: Text(c.displayName),
                  onDeleted: contacts.length > 1
                      ? () => ref
                            .read(broadcastDraftProvider.notifier)
                            .remove(c.id)
                      : null,
                  deleteButtonTooltipMessage: 'Remove ${c.displayName}',
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Send with'),
          SegmentedButton<BroadcastChannel>(
            segments: const [
              ButtonSegment(
                value: BroadcastChannel.whatsApp,
                label: Text('WhatsApp'),
                icon: WhatsAppIcon(size: 18),
              ),
              ButtonSegment(
                value: BroadcastChannel.sms,
                label: Text('SMS'),
                icon: Icon(Icons.sms_outlined, size: 18),
              ),
            ],
            selected: {draft.channel},
            onSelectionChanged: (s) =>
                ref.read(broadcastDraftProvider.notifier).setChannel(s.first),
          ),
          if (skipped > 0) ...[
            const SizedBox(height: 10),
            _Notice(
              text: draft.channel == BroadcastChannel.whatsApp
                  ? '$skipped ${skipped == 1 ? 'contact has' : 'contacts have'} '
                        'no number with a country code and will be skipped. '
                        'Try SMS, or set a default region in Settings.'
                  : '$skipped ${skipped == 1 ? 'contact has' : 'contacts have'} '
                        'no dialable number and will be skipped.',
            ),
          ],
          if (lateNight > 0) ...[
            const SizedBox(height: 10),
            _Notice(
              key: const Key('late-night-notice'),
              text:
                  'It’s late at night for $lateNight '
                  '${lateNight == 1 ? 'recipient' : 'recipients'} right now '
                  '(9 PM – 8 AM their time). You may want to send later.',
            ),
          ],
          const SizedBox(height: 20),
          const _Label('Message'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Insert:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final token in NameToken.values)
                ActionChip(
                  key: ValueKey('insert-${token.key}'),
                  avatar: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(token.label),
                  onPressed: () => _insert(token.placeholder),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('broadcast-field'),
            controller: _controller,
            focusNode: _focus,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Hi {first_name}, …'),
          ),
          const SizedBox(height: 10),
          // Wraps so the save and manage actions are always visible.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in templates) ...[
                ActionChip(
                  key: ValueKey('template-${t.id}'),
                  avatar: const Icon(Icons.bookmark_outline_rounded, size: 18),
                  label: Text(t.title),
                  onPressed: () => _applyTemplate(t.body),
                ),
              ],
              ValueListenableBuilder(
                key: const ValueKey('save-template-slot'),
                valueListenable: _controller,
                builder: (context, value, _) => ActionChip(
                  key: const Key('save-template'),
                  avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save as template'),
                  onPressed: value.text.trim().isEmpty
                      ? null
                      : () => showSaveTemplateDialog(context, ref, value.text),
                ),
              ),
              ActionChip(
                key: const Key('manage-templates'),
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Manage'),
                onPressed: () async {
                  final picked = await showTemplatesSheet(context);
                  if (picked != null) _applyTemplate(picked.body);
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (reachable.isNotEmpty)
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => ValueListenableBuilder(
                valueListenable: _previewIndex,
                builder: (context, index, _) => _Preview(
                  contacts: reachable,
                  index: index.clamp(0, reachable.length - 1),
                  template: value.text,
                  channel: draft.channel,
                  onChange: (i) => _previewIndex.value = i,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton.icon(
            key: const Key('review-send'),
            onPressed: value.text.trim().isEmpty || reachable.isEmpty
                ? null
                : () => _review(contacts, draft),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              reachable.length == 1
                  ? 'Review & send to 1 contact'
                  : 'Review & send to ${reachable.length} contacts',
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? const Color(0xFFFFC870)
        : const Color(0xFF8A5300);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC870).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the message exactly as one recipient will receive it.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.contacts,
    required this.index,
    required this.template,
    required this.channel,
    required this.onChange,
  });

  final List<AppContact> contacts;
  final int index;
  final String template;
  final BroadcastChannel channel;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contact = contacts[index];
    final text = MessageTemplate.render(template, contact);
    final dark = theme.brightness == Brightness.dark;
    final bubble = channel == BroadcastChannel.whatsApp
        ? (dark ? const Color(0xFF144D37) : const Color(0xFFD9FDD3))
        : (dark ? const Color(0xFF1F3A70) : const Color(0xFFDCE7FF));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ContactAvatar(contact: contact, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Preview for ${contact.displayName}',
                  key: const Key('preview-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Previous preview',
                onPressed: index > 0 ? () => onChange(index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${index + 1}/${contacts.length}',
                style: theme.textTheme.labelMedium,
              ),
              IconButton(
                tooltip: 'Next preview',
                onPressed: index < contacts.length - 1
                    ? () => onChange(index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: bubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                text.isEmpty ? 'Your message will appear here' : text,
                key: const Key('preview-text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: text.isEmpty ? scheme.onSurfaceVariant : null,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
