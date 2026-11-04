import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/saved_template.dart';
import 'templates_providers.dart';

/// Asks for a name and saves [body] as a template.
Future<void> showSaveTemplateDialog(
  BuildContext context,
  WidgetRef ref,
  String body,
) async {
  // Captured first: saving adds a chip, which can rebuild the caller.
  final messenger = ScaffoldMessenger.of(context);
  final title = await showDialog<String>(
    context: context,
    builder: (_) => const _NameTemplateDialog(),
  );
  if (title == null || title.trim().isEmpty) return;
  await ref.read(savedTemplatesProvider.notifier).add(title, body);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Saved “${title.trim()}”.')));
}

class _NameTemplateDialog extends StatefulWidget {
  const _NameTemplateDialog();

  @override
  State<_NameTemplateDialog> createState() => _NameTemplateDialogState();
}

class _NameTemplateDialogState extends State<_NameTemplateDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save as template'),
    content: TextField(
      key: const Key('template-name'),
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Name, e.g. Eid greeting'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('template-save'),
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// Lists saved templates; tapping one returns it, the bin deletes it.
Future<SavedTemplate?> showTemplatesSheet(BuildContext context) =>
    showModalBottomSheet<SavedTemplate>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _TemplatesSheet(),
    );

class _TemplatesSheet extends ConsumerWidget {
  const _TemplatesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templates = ref.watch(savedTemplatesProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text('Templates', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Tap a template to use it. Save new ones from the message box.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: templates.isEmpty
                ? Center(
                    child: Text(
                      'No saved templates',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = templates[i];
                      return ListTile(
                        key: ValueKey('saved-${t.id}'),
                        contentPadding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
                        title: Text(t.title),
                        subtitle: Text(
                          t.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, t),
                        trailing: IconButton(
                          tooltip: 'Delete ${t.title}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => ref
                              .read(savedTemplatesProvider.notifier)
                              .remove(t.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
