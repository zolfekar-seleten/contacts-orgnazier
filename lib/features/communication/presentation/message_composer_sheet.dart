import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../contacts/domain/app_contact.dart';
import '../domain/communication_kind.dart';

/// Lets the user write or pick a message before handing off to WhatsApp or
/// Messages. Returns the message, or null if dismissed.
Future<String?> showMessageComposer(
  BuildContext context, {
  required AppContact contact,
  required ClassifiedPhone phone,
  CommunicationKind kind = CommunicationKind.whatsApp,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      MessageComposerSheet(contact: contact, phone: phone, kind: kind),
);

class MessageComposerSheet extends StatefulWidget {
  const MessageComposerSheet({
    super.key,
    required this.contact,
    required this.phone,
    this.kind = CommunicationKind.whatsApp,
  });

  final AppContact contact;
  final ClassifiedPhone phone;

  /// [CommunicationKind.whatsApp] or [CommunicationKind.sms].
  final CommunicationKind kind;

  static List<String> templatesFor(String firstName) {
    final first = firstName.isEmpty ? 'there' : firstName;
    return [
      'Hi $first! 👋',
      'Hi $first, do you have a minute for a quick call?',
      'Running a few minutes late, see you soon.',
      'Thanks, talk soon!',
    ];
  }

  @override
  State<MessageComposerSheet> createState() => _MessageComposerSheetState();
}

class _MessageComposerSheetState extends State<MessageComposerSheet> {
  final _controller = TextEditingController();
  late final _templates = MessageComposerSheet.templatesFor(
    widget.contact.firstName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyTemplate(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final country = widget.phone.country;
    final sms = widget.kind == CommunicationKind.sms;
    final appName = widget.kind.appName;
    // SMS can go to a local number; WhatsApp always uses the E.164 form.
    final shownNumber = sms
        ? widget.phone.raw
        : (widget.phone.e164 ?? widget.phone.raw);
    // Scrolls when the keyboard or large text leaves too little room.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (sms)
                const Icon(Icons.sms_rounded, size: 28, color: AppColors.sms)
              else
                const WhatsAppIcon(size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message ${widget.contact.displayName}',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${country?.flag ?? ''} $shownNumber'.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('composer-field'),
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Write a message…'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final text = _templates[i];
                return ActionChip(
                  label: Text(text, maxLines: 1),
                  onPressed: () => _applyTemplate(text),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: sms
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.sms,
                    foregroundColor: Colors.white,
                  )
                : FilledButton.styleFrom(
                    backgroundColor: AppColors.whatsApp,
                    foregroundColor: const Color(0xFF06331B),
                  ),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text('Continue to $appName'),
          ),
          const SizedBox(height: 10),
          Text(
            '$appName will open with this message filled in. Nothing is sent '
            'until you tap send there.',
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
