import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_view.dart';
import '../../countries/domain/country.dart';
import '../../crm/data/crm_database.dart';
import '../../crm/presentation/crm_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/file_source.dart';
import '../data/importer.dart';
import '../domain/column_detection.dart';
import '../domain/import_plan.dart';
import '../domain/table_reader.dart';

/// Imports leads or clients from an Excel or CSV file: choose a file,
/// check the columns it recognised, preview, import.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.kind});

  final PartyKind kind;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late var _kind = widget.kind;
  String? _fileName;
  List<ImportTable> _tables = const [];
  var _sheet = 0;
  int? _headerRow;
  List<ImportField> _fields = const [];
  List<ImportField> _detected = const [];
  Set<String> _saved = const {};
  String? _error;
  var _busy = false;
  int? _imported;
  ImportPlan? _resultPlan;

  ImportTable? get _table => _tables.isEmpty ? null : _tables[_sheet];

  Future<void> _pick() async {
    setState(() => _error = null);
    final file = await ref.read(spreadsheetSourceProvider).pick();
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final tables = readSpreadsheet(file.name, file.bytes);
      if (tables.isEmpty) {
        throw const UnsupportedFileException('This file is empty.');
      }
      final saved = await ref.read(crmRepositoryProvider).savedNumbers();
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _tables = tables;
        _saved = saved;
        _selectSheet(0);
      });
    } on UnsupportedFileException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectSheet(int i) {
    _sheet = i;
    final layout = detectLayout(_tables[i].rows);
    _headerRow = layout.headerRow;
    _detected = [for (final c in layout.columns) c.field];
    _fields = [..._detected];
  }

  ImportPlan? _plan() {
    final table = _table;
    if (table == null) return null;
    final statuses = ref.watch(leadStatusesProvider).value ?? const [];
    return planImport(
      rows: table.rows,
      firstDataRow: (_headerRow ?? -1) + 1,
      fields: _fields,
      kind: _kind,
      existingNumbers: _saved,
      statuses: {for (final s in statuses) s.name: s.id},
      defaultDialCode: Country.fromIso(
        ref.watch(effectiveRegionProvider),
      )?.dialCode,
    );
  }

  Future<void> _run(ImportPlan plan) async {
    setState(() => _busy = true);
    final count = await runImport(
      ref.read(crmRepositoryProvider),
      plan,
      kind: _kind,
      statuses: ref.read(leadStatusesProvider).value ?? const [],
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _imported = count;
      _resultPlan = plan;
    });
  }

  String get _noun => _kind == PartyKind.lead ? 'lead' : 'client';

  @override
  Widget build(BuildContext context) {
    final plan = _plan();
    final hasName = _fields.any(
      (f) =>
          f == ImportField.name ||
          f == ImportField.firstName ||
          f == ImportField.lastName,
    );
    final ready = plan?.ready.length ?? 0;

    if (_imported != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import')),
        body: StateView(
          key: const Key('import-result'),
          icon: Icons.check_circle_outline_rounded,
          title: 'Imported $_imported ${_imported == 1 ? _noun : '${_noun}s'}',
          message: [
            if (_resultPlan!.duplicates > 0)
              '${_resultPlan!.duplicates} skipped as duplicates.',
            if (_resultPlan!.missingName > 0)
              '${_resultPlan!.missingName} skipped without a name.',
            if (_resultPlan!.newStatuses.isNotEmpty)
              'New statuses: ${_resultPlan!.newStatuses.join(', ')}.',
          ].join(' ').ifEmpty('Everything in the file was added.'),
          primaryLabel: 'Done',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      );
    }

    final padding = contentPadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Excel')),
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                key: const Key('import-run'),
                onPressed: _busy || ready == 0 || !hasName
                    ? null
                    : () => _run(plan),
                icon: const Icon(Icons.download_done_rounded),
                label: Text(
                  'Import $ready ${ready == 1 ? _noun : '${_noun}s'}',
                ),
              ),
            ),
      body: ListView(
        padding: padding.copyWith(top: 4, bottom: 32),
        children: [
          SegmentedButton<PartyKind>(
            key: const Key('import-kind'),
            segments: const [
              ButtonSegment(value: PartyKind.lead, label: Text('As leads')),
              ButtonSegment(value: PartyKind.client, label: Text('As clients')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          if (_table == null)
            _Intro(busy: _busy, error: _error, onPick: _pick)
          else ...[
            _FileHeader(
              fileName: _fileName!,
              rows: _table!.rows.length - (_headerRow ?? -1) - 1,
              onChange: _busy ? null : _pick,
            ),
            if (_tables.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _sheet,
                decoration: const InputDecoration(labelText: 'Sheet'),
                items: [
                  for (final (i, t) in _tables.indexed)
                    DropdownMenuItem(value: i, child: Text(t.name)),
                ],
                onChanged: (i) => setState(() => _selectSheet(i!)),
              ),
            ],
            SwitchListTile(
              key: const Key('import-header'),
              contentPadding: EdgeInsets.zero,
              title: const Text('First row has column names'),
              value: _headerRow != null,
              onChanged: (v) => setState(() => _headerRow = v ? 0 : null),
            ),
            if (_error != null) _ErrorText(_error!),
            _Section('Columns'),
            Text(
              'Recognised automatically. Change any that look wrong.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _fields.length; i++)
              _ColumnCard(
                key: ValueKey('column-$i'),
                index: i,
                header: _headerRow == null
                    ? null
                    : _table!.rows[_headerRow!][i],
                samples: [
                  for (final r in _table!.rows.skip((_headerRow ?? -1) + 1))
                    if (r[i].isNotEmpty) r[i],
                ].take(3).toList(),
                field: _fields[i],
                auto:
                    _fields[i] == _detected[i] &&
                    _fields[i] != ImportField.ignore,
                onChanged: (f) =>
                    setState(() => _fields = [..._fields]..[i] = f),
              ),
            if (!hasName)
              const _ErrorText(
                'Choose the column that has the name (or first and last '
                'name).',
              ),
            if (plan != null) _Summary(plan: plan, kind: _kind),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _Intro extends StatelessWidget {
  const _Intro({required this.busy, required this.error, required this.onPick});

  final bool busy;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.hero(theme.brightness),
            borderRadius: BorderRadius.circular(AppTheme.radius + 6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.table_view_rounded,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                'Bring in your list',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an Excel (.xlsx) or CSV file. Columns are matched '
                'for you, whatever they’re called.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('import-pick'),
          onPressed: busy ? null : onPick,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: const Text('Choose file'),
        ),
        if (error != null) _ErrorText(error!),
        const SizedBox(height: 20),
        Text('Recognised columns', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Name (or first + last name), mobile, country code, nationality, '
          'country, source, sub source and status — in English or Arabic, '
          'with or without a header row.',
          style: muted,
        ),
        const SizedBox(height: 12),
        Text('Phone numbers', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          '+971…, 00971…, numbers saved without the +, or local numbers '
          '(your default region is used). People already saved, and '
          'repeats in the file, are skipped.',
          style: muted,
        ),
      ],
    );
  }
}

class _FileHeader extends StatelessWidget {
  const _FileHeader({
    required this.fileName,
    required this.rows,
    required this.onChange,
  });

  final String fileName;
  final int rows;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.description_outlined, color: theme.colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                '$rows ${rows == 1 ? 'row' : 'rows'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onChange, child: const Text('Change')),
      ],
    );
  }
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    super.key,
    required this.index,
    required this.header,
    required this.samples,
    required this.field,
    required this.auto,
    required this.onChanged,
  });

  final int index;
  final String? header;
  final List<String> samples;
  final ImportField field;
  final bool auto;
  final ValueChanged<ImportField> onChanged;

  /// "A", "B", … "AA" like spreadsheet columns.
  static String letter(int i) => i < 26
      ? String.fromCharCode(65 + i)
      : letter(i ~/ 26 - 1) + letter(i % 26);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ignored = field == ImportField.ignore;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ignored ? scheme.surfaceContainerLow : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (header == null || header!.isEmpty)
                        ? 'Column ${letter(index)}'
                        : header!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ignored ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  Text(
                    samples.isEmpty ? 'Empty' : samples.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (auto)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: scheme.secondary,
                  semanticLabel: 'Detected automatically',
                ),
              ),
            DropdownButton<ImportField>(
              key: ValueKey('map-$index'),
              value: field,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(14),
              items: [
                for (final f in ImportField.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (f) => onChanged(f!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.kind});

  final ImportPlan plan;
  final PartyKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = plan.ready.take(3).toList();
    Widget stat(String label, int value, Color color, Key key) => Expanded(
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section('Preview'),
        Row(
          children: [
            stat(
              'Ready',
              plan.ready.length,
              const Color(0xFF22B07D),
              const Key('import-ready'),
            ),
            const SizedBox(width: 8),
            stat(
              'Duplicates',
              plan.duplicates,
              const Color(0xFFF5A524),
              const Key('import-duplicates'),
            ),
            const SizedBox(width: 8),
            stat(
              'No name',
              plan.missingName,
              scheme.onSurfaceVariant,
              const Key('import-noname'),
            ),
          ],
        ),
        if (kind == PartyKind.lead && plan.newStatuses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'New statuses will be added: ${plan.newStatuses.join(', ')}',
            key: const Key('import-new-statuses'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 10),
        for (final r in preview)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(r.name),
              subtitle: Text(
                [
                  ?r.e164,
                  if (Country.fromIso(r.data!.nationality.value) case final c?)
                    '${c.flag} ${c.name}',
                  ?r.data!.source.value,
                  if (kind == PartyKind.lead) ?r.statusName,
                ].join(' · '),
              ),
            ),
          ),
        if (plan.ready.length > preview.length)
          Text(
            '…and ${plan.ready.length - preview.length} more',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 18, bottom: 6),
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      text,
      key: const Key('import-error'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
