import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flag_badge.dart';
import '../../countries/domain/country.dart';
import '../../settings/presentation/region_picker_screen.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/crm_database.dart';
import '../domain/party_phone.dart';
import 'crm_providers.dart';

/// Adds or edits a lead or client. Pops with the saved id.
class PartyFormScreen extends ConsumerStatefulWidget {
  const PartyFormScreen({super.key, required this.kind, this.party});

  final PartyKind kind;

  /// The record being edited; null to add a new one.
  final Party? party;

  @override
  ConsumerState<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends ConsumerState<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.party?.name);
  late final _mobile = TextEditingController(text: widget.party?.mobile);
  late final _source = TextEditingController(text: widget.party?.source);
  late final _subSource = TextEditingController(text: widget.party?.subSource);
  late String? _dialCode;
  late String? _nationality = widget.party?.nationality;
  late String? _country;
  late String? _statusId = widget.party?.statusId;
  bool _saving = false;

  bool get _editing => widget.party != null;
  bool get _lead => widget.kind == PartyKind.lead;

  @override
  void initState() {
    super.initState();
    // New records default to the user's region.
    final region = _editing ? null : ref.read(effectiveRegionProvider);
    _dialCode = widget.party?.dialCode ?? Country.fromIso(region)?.dialCode;
    _country = widget.party?.country ?? region;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _source.dispose();
    _subSource.dispose();
    super.dispose();
  }

  Future<Country?> _pickCountry(String title) =>
      Navigator.of(context).push<Country>(
        MaterialPageRoute(builder: (_) => RegionPickerScreen(title: title)),
      );

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final phone = splitPhone(_mobile.text, dialCode: _dialCode);
    final statuses = ref.read(leadStatusesProvider).value ?? const [];
    final data = PartiesCompanion(
      name: Value(_name.text.trim()),
      dialCode: Value(phone.national == null ? _dialCode : phone.dialCode),
      mobile: Value(phone.national),
      nationality: Value(_nationality),
      country: Value(_country),
      source: Value(_text(_source)),
      subSource: Value(_text(_subSource)),
      statusId: Value(
        _lead ? (_statusId ?? statuses.firstOrNull?.id) : _statusId,
      ),
    );
    final repo = ref.read(crmRepositoryProvider);
    final String id;
    if (_editing) {
      id = widget.party!.id;
      await repo.updateParty(id, data);
    } else {
      id = await repo.createParty(data.copyWith(kind: Value(widget.kind)));
    }
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = contentPadding(context);
    final statuses = ref.watch(leadStatusesProvider).value ?? const [];
    final selectedStatus = _statusId ?? statuses.firstOrNull?.id;
    final noun = _lead ? 'lead' : 'client';

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit $noun' : 'New $noun'),
        actions: [
          TextButton(
            key: const Key('party-save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: padding.copyWith(top: 8, bottom: 32),
          children: [
            const _Label('Name'),
            TextFormField(
              key: const Key('party-name'),
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(hintText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 18),
            const _Label('Mobile'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PickerButton(
                  key: const Key('party-dial'),
                  country: _dialCode == null
                      ? null
                      : Country.all
                            .where((c) => c.dialCode == _dialCode)
                            .firstOrNull,
                  label: _dialCode == null ? 'Code' : '+$_dialCode',
                  onTap: () async {
                    final c = await _pickCountry('Calling code');
                    if (c != null) setState(() => _dialCode = c.dialCode);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: const Key('party-mobile'),
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: const InputDecoration(hintText: '50 123 4567'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Label('Nationality'),
                      _PickerButton(
                        key: const Key('party-nationality'),
                        country: Country.fromIso(_nationality),
                        label: Country.fromIso(_nationality)?.name ?? 'Choose',
                        onTap: () async {
                          final c = await _pickCountry('Nationality');
                          if (c != null) {
                            setState(() => _nationality = c.isoCode);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Label('Country'),
                      _PickerButton(
                        key: const Key('party-country'),
                        country: Country.fromIso(_country),
                        label: Country.fromIso(_country)?.name ?? 'Choose',
                        onTap: () async {
                          final c = await _pickCountry('Country');
                          if (c != null) setState(() => _country = c.isoCode);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('Source'),
            _SuggestField(
              key: const Key('party-source'),
              controller: _source,
              hint: 'e.g. Instagram, Referral, Walk-in',
              suggestions: ref.watch(sourceSuggestionsProvider).value,
            ),
            const SizedBox(height: 18),
            const _Label('Sub source'),
            _SuggestField(
              key: const Key('party-subsource'),
              controller: _subSource,
              hint: 'e.g. Campaign or person who referred',
              suggestions: ref.watch(subSourceSuggestionsProvider).value,
            ),
            if (_lead) ...[
              const SizedBox(height: 18),
              const _Label('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in statuses)
                    ChoiceChip(
                      key: ValueKey('form-status-${s.name}'),
                      avatar: CircleAvatar(
                        backgroundColor: Color(s.color),
                        radius: 5,
                      ),
                      label: Text(s.name),
                      selected: selectedStatus == s.id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _statusId = s.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save changes' : 'Add $noun'),
            ),
            if (!_editing) ...[
              const SizedBox(height: 10),
              Text(
                'Saved on this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
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

/// A field-shaped button that opens a country picker.
class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.country,
    required this.label,
    required this.onTap,
  });

  final Country? country;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          theme.inputDecorationTheme.fillColor ??
          theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (country != null) ...[
                FlagBadge(country: country, size: 24),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field that suggests values used before.
class _SuggestField extends StatefulWidget {
  const _SuggestField({
    super.key,
    required this.controller,
    required this.hint,
    required this.suggestions,
  });

  final TextEditingController controller;
  final String hint;
  final List<String>? suggestions;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return (widget.suggestions ?? const <String>[]).where(
          (s) => s.toLowerCase().contains(q) && s.toLowerCase() != q,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.sentences,
            onTapOutside: (_) => focusNode.unfocus(),
            decoration: InputDecoration(hintText: widget.hint),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
