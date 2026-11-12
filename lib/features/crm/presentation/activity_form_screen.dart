import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/attachment_store.dart';
import '../data/crm_database.dart';
import 'activity_widgets.dart';
import 'crm_providers.dart';
import 'who_picker_sheet.dart';

/// Adds or edits an activity: type, priority, when, with who, a styled
/// note and images.
class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({super.key, this.activity, this.initialWho});

  /// The activity to edit; null to add one.
  final Activity? activity;

  /// Prefills "with who" for a new activity (e.g. from a lead's page).
  final ActivityWho? initialWho;

  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _noteScroll = ScrollController();
  QuillController? _note;
  Activity? _existing;

  var _type = ActivityType.call;
  var _priority = ActivityPriority.medium;
  DateTime? _due;
  ActivityWho? _who;
  var _done = false;

  /// Kept from the start: `ref` can't be used in [dispose].
  late final AttachmentStore _store;

  /// Images copied in during this edit, and saved ones the user removed.
  final _added = <String>[];
  final _removed = <String>{};
  var _saved = false;

  bool get _editing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    _store = ref.read(attachmentStoreProvider);
    final a = widget.activity;
    if (a == null) {
      _who = widget.initialWho;
      _note = QuillController.basic();
      return;
    }
    final parties = ref.read(partiesByIdProvider);
    _existing = a;
    _type = a.type;
    _priority = a.priority;
    _due = a.dueAt;
    _done = a.completedAt != null;
    _title.text = a.title;
    _who = (a.partyId != null || a.contactId != null)
        ? (
            partyId: a.partyId,
            contactId: a.contactId,
            name: activityWho(a, parties) ?? '',
          )
        : null;
    _note = QuillController(
      document: a.noteJson == null
          ? Document()
          : Document.fromJson(jsonDecode(a.noteJson!) as List),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    // Images added but never saved are not kept.
    if (!_saved) {
      for (final f in _added) {
        _store.delete(f);
      }
    }
    _title.dispose();
    _titleFocus.dispose();
    _noteFocus.dispose();
    _noteScroll.dispose();
    _note?.dispose();
    super.dispose();
  }

  Future<void> _addImages({required bool camera}) async {
    final source = ref.read(imageSourceProvider);
    final picked = camera
        ? [?await source.takePhoto()]
        : await source.pickFromLibrary();
    for (final image in picked) {
      final name = await _store.save(image);
      if (!mounted) return;
      setState(() => _added.add(name));
    }
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _due ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _due == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(_due!),
      helpText: 'Time (optional)',
    );
    setState(
      () => _due = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
    );
  }

  Future<void> _save() async {
    final note = _note!;
    final plain = note.document.toPlainText().trim();
    final title = _title.text.trim().isNotEmpty
        ? _title.text.trim()
        : _who == null
        ? _type.label
        : '${_type.label} with ${_who!.name}';
    final data = ActivitiesCompanion(
      type: Value(_type),
      priority: Value(_priority),
      title: Value(title),
      dueAt: Value(_due),
      noteJson: Value(
        plain.isEmpty ? null : jsonEncode(note.document.toDelta().toJson()),
      ),
      notePlain: Value(plain.isEmpty ? null : plain),
      partyId: Value(_who?.partyId),
      contactId: Value(_who?.contactId),
      contactName: Value(_who?.contactId == null ? null : _who!.name),
      completedAt: Value(
        _done ? (_existing?.completedAt ?? DateTime.now()) : null,
      ),
    );
    final repo = ref.read(activityRepositoryProvider);
    if (_editing) {
      await repo.updateActivity(widget.activity!.id, data);
      for (final f in _added) {
        await repo.addAttachment(widget.activity!.id, f);
      }
      final existing = ref.read(attachmentsProvider(widget.activity!.id)).value;
      for (final a in existing ?? const <ActivityAttachment>[]) {
        if (_removed.contains(a.id)) {
          await repo.deleteAttachment(a.id);
          await _store.delete(a.fileName);
        }
      }
    } else {
      await repo.createActivity(data, attachments: _added);
    }
    _saved = true;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('activity-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final files = await ref
        .read(activityRepositoryProvider)
        .deleteActivity(widget.activity!.id);
    for (final f in files) {
      await _store.delete(f);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = contentPadding(context);
    final saved = _editing
        ? (ref.watch(attachmentsProvider(widget.activity!.id)).value ??
                  const <ActivityAttachment>[])
              .where((a) => !_removed.contains(a.id))
              .toList()
        : const <ActivityAttachment>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Activity' : 'New activity'),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('activity-delete'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          TextButton(
            key: const Key('activity-save'),
            onPressed: note == null ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: note == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding.copyWith(top: 4, bottom: 40),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ActivityType.values)
                      ChoiceChip(
                        key: ValueKey('type-${t.name}'),
                        avatar: Icon(
                          t.icon,
                          size: 18,
                          color: _type == t ? t.color : scheme.onSurfaceVariant,
                        ),
                        label: Text(t.label),
                        selected: _type == t,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('activity-title'),
                  controller: _title,
                  focusNode: _titleFocus,
                  textCapitalization: TextCapitalization.sentences,
                  onTapOutside: (_) => _titleFocus.unfocus(),
                  decoration: InputDecoration(
                    hintText: _who == null
                        ? 'Title (optional)'
                        : '${_type.label} with ${_who!.name}',
                  ),
                ),
                const SizedBox(height: 16),
                const _Label('Priority'),
                SegmentedButton<ActivityPriority>(
                  segments: [
                    for (final p in ActivityPriority.values)
                      ButtonSegment(
                        value: p,
                        label: Text(p.label),
                        icon: Icon(
                          Icons.flag_rounded,
                          size: 16,
                          color: p.color,
                        ),
                      ),
                  ],
                  selected: {_priority},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
                const SizedBox(height: 16),
                _FieldTile(
                  key: const Key('activity-when'),
                  icon: Icons.event_outlined,
                  label: 'When',
                  value: _due == null
                      ? 'No date'
                      : formatDue(context, _due!, DateTime.now()),
                  onTap: _pickDue,
                  onClear: _due == null
                      ? null
                      : () => setState(() => _due = null),
                ),
                const SizedBox(height: 10),
                _FieldTile(
                  key: const Key('activity-with'),
                  icon: Icons.person_outline_rounded,
                  label: 'With',
                  value: _who?.name ?? 'Lead, client or contact',
                  onTap: () async {
                    final who = await showWhoPicker(context);
                    if (who != null) setState(() => _who = who);
                  },
                  onClear: _who == null
                      ? null
                      : () => setState(() => _who = null),
                ),
                const SizedBox(height: 18),
                const _Label('Note'),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuillSimpleToolbar(
                        controller: note,
                        config: const QuillSimpleToolbarConfig(
                          multiRowsDisplay: false,
                          showFontFamily: false,
                          showFontSize: false,
                          showInlineCode: false,
                          showBackgroundColorButton: false,
                          showCodeBlock: false,
                          showQuote: false,
                          showIndent: false,
                          showLink: false,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      QuillEditor(
                        controller: note,
                        focusNode: _noteFocus,
                        scrollController: _noteScroll,
                        config: QuillEditorConfig(
                          scrollable: false,
                          minHeight: 140,
                          padding: const EdgeInsets.all(14),
                          placeholder: 'Add notes…',
                          onTapOutside: (_, _) => _noteFocus.unfocus(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: _Label('Images')),
                    TextButton.icon(
                      key: const Key('add-photos'),
                      onPressed: () => _addImages(camera: false),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Photos'),
                    ),
                    TextButton.icon(
                      key: const Key('take-photo'),
                      onPressed: () => _addImages(camera: true),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
                if (saved.isEmpty && _added.isEmpty)
                  Text(
                    'No images',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in saved)
                        _Thumbnail(
                          key: ValueKey('image-${a.fileName}'),
                          fileName: a.fileName,
                          onRemove: () => setState(() => _removed.add(a.id)),
                        ),
                      for (final f in _added)
                        _Thumbnail(
                          key: ValueKey('image-$f'),
                          fileName: f,
                          onRemove: () {
                            setState(() => _added.remove(f));
                            _store.delete(f);
                          },
                        ),
                    ],
                  ),
                if (_editing) ...[
                  const SizedBox(height: 18),
                  SwitchListTile(
                    key: const Key('activity-done'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Done'),
                    value: _done,
                    onChanged: (v) => setState(() => _done = v),
                  ),
                ],
              ],
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

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.secondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear ${label.toLowerCase()}',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClear,
                )
              else
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stored image with a remove button; tap to view full screen.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({super.key, required this.fileName, required this.onRemove});

  final String fileName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<File>(
      future: ref.read(attachmentStoreProvider).file(fileName),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: file == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ImageViewer(file: file),
                      ),
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: file == null
                      ? const ColoredBox(color: Colors.black12)
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 264,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: IconButton.filled(
                tooltip: 'Remove image',
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(child: Image.file(file)),
    ),
  );
}
