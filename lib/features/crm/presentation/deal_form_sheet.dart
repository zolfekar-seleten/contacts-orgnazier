import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crm_database.dart';
import 'crm_providers.dart';
import 'crm_widgets.dart';

/// Adds or edits what a client bought or rented.
Future<void> showDealForm(
  BuildContext context, {
  required String partyId,
  Deal? deal,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _DealForm(partyId: partyId, deal: deal),
);

class _DealForm extends ConsumerStatefulWidget {
  const _DealForm({required this.partyId, this.deal});

  final String partyId;
  final Deal? deal;

  @override
  ConsumerState<_DealForm> createState() => _DealFormState();
}

class _DealFormState extends ConsumerState<_DealForm> {
  final _formKey = GlobalKey<FormState>();
  late var _type = widget.deal?.type ?? DealType.bought;
  late var _date = widget.deal?.date ?? DateTime.now();
  late final _item = TextEditingController(text: widget.deal?.item);
  late final _location = TextEditingController(text: widget.deal?.location);
  late final _notes = TextEditingController(text: widget.deal?.notes);

  @override
  void dispose() {
    _item.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(crmRepositoryProvider);
    final data = DealsCompanion(
      type: Value(_type),
      item: Value(_item.text.trim()),
      date: Value(_date),
      location: Value(_text(_location)),
      notes: Value(_text(_notes)),
    );
    if (widget.deal == null) {
      await repo.createDeal(data.copyWith(partyId: Value(widget.partyId)));
    } else {
      await repo.updateDeal(widget.deal!.id, data);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(crmRepositoryProvider).deleteDeal(widget.deal!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void unfocus(PointerDownEvent _) => FocusScope.of(context).unfocus();
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.deal == null ? 'Add purchase or rental' : 'Edit',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<DealType>(
              segments: [
                for (final t in DealType.values)
                  ButtonSegment(
                    value: t,
                    label: Text(t.label),
                    icon: Icon(
                      t == DealType.bought
                          ? Icons.sell_outlined
                          : Icons.key_outlined,
                      size: 18,
                    ),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('deal-item'),
              controller: _item,
              autofocus: widget.deal == null,
              textCapitalization: TextCapitalization.sentences,
              onTapOutside: unfocus,
              decoration: const InputDecoration(
                labelText: 'What',
                hintText: 'e.g. 2BR apartment, car, membership',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter what it was' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('deal-date'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.event_outlined),
              label: Text('When: ${formatDate(context, _date)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('deal-location'),
              controller: _location,
              textCapitalization: TextCapitalization.words,
              onTapOutside: unfocus,
              decoration: const InputDecoration(
                labelText: 'Where',
                hintText: 'e.g. Dubai Marina, Tower B',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('deal-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onTapOutside: unfocus,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('deal-save'),
              onPressed: _save,
              child: const Text('Save'),
            ),
            if (widget.deal != null)
              TextButton(
                key: const Key('deal-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _delete,
                child: const Text('Delete'),
              ),
          ],
        ),
      ),
    );
  }
}
