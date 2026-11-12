import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/crm_database.dart';
import 'crm_providers.dart';
import 'crm_widgets.dart';

/// Add, rename, recolour, reorder and delete lead statuses.
class StatusManagerScreen extends ConsumerWidget {
  const StatusManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(leadStatusesProvider).value ?? const [];
    final leads = ref.watch(partiesProvider(PartyKind.lead)).value ?? const [];
    final repo = ref.read(crmRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Lead statuses')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-status'),
        onPressed: () async {
          final result = await _editStatus(context);
          if (result != null) await repo.addStatus(result.$1, result.$2);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add status'),
      ),
      body: Column(
        children: [
          Padding(
            padding: contentPadding(context).copyWith(top: 4, bottom: 8),
            child: Text(
              'Drag to reorder. The first status is used for new leads.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: contentPadding(context).copyWith(bottom: 96),
              itemCount: statuses.length,
              onReorderItem: (from, to) {
                final ids = [for (final s in statuses) s.id];
                ids.insert(to, ids.removeAt(from));
                repo.reorderStatuses(ids);
              },
              itemBuilder: (context, i) {
                final s = statuses[i];
                final count = leads.where((l) => l.statusId == s.id).length;
                return Card(
                  key: ValueKey(s.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(s.color),
                      radius: 10,
                    ),
                    title: Text(s.name),
                    subtitle: Text('$count ${count == 1 ? 'lead' : 'leads'}'),
                    onTap: () async {
                      final result = await _editStatus(context, status: s);
                      if (result != null) {
                        await repo.updateStatus(
                          s.id,
                          name: result.$1,
                          color: result.$2,
                        );
                      }
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Delete ${s.name}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: statuses.length < 2
                              ? null
                              : () => _delete(context, ref, s, statuses),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LeadStatus status,
    List<LeadStatus> statuses,
  ) async {
    final others = [
      for (final s in statuses)
        if (s.id != status.id) s,
    ];
    final moveTo = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Delete “${status.name}”?'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Move its leads to:'),
          ),
          for (final s in others)
            SimpleDialogOption(
              key: ValueKey('move-to-${s.name}'),
              onPressed: () => Navigator.pop(context, s.id),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: Color(s.color), radius: 7),
                  const SizedBox(width: 12),
                  Text(s.name),
                ],
              ),
            ),
        ],
      ),
    );
    if (moveTo == null) return;
    await ref
        .read(crmRepositoryProvider)
        .deleteStatus(status.id, moveLeadsTo: moveTo);
  }
}

/// Name and colour dialog; returns null when cancelled.
Future<(String, int)?> _editStatus(
  BuildContext context, {
  LeadStatus? status,
}) => showDialog<(String, int)>(
  context: context,
  builder: (_) => _StatusDialog(status: status),
);

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({this.status});

  final LeadStatus? status;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late final _name = TextEditingController(text: widget.status?.name);
  late int _color = widget.status?.color ?? statusPalette[2];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, (_name.text.trim(), _color));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.status == null ? 'New status' : 'Edit status'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('status-name'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Warm, Viewing'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in statusPalette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: _color == c
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('status-save'),
        onPressed: _submit,
        child: const Text('Save'),
      ),
    ],
  );
}
