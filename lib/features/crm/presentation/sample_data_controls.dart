import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/sample_data.dart';
import 'crm_providers.dart';

final sampleDataProvider = Provider(
  (ref) => SampleData(
    ref.watch(crmDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Whether the sample set is in the database.
class SampleDataLoaded extends Notifier<bool> {
  @override
  bool build() => ref.watch(sampleDataProvider).isLoaded;

  Future<String> add() async {
    final (leads, clients, activities) = await ref
        .read(sampleDataProvider)
        .add();
    state = true;
    return 'Added $leads leads, $clients clients and $activities activities.';
  }

  Future<void> remove() async {
    await ref.read(sampleDataProvider).remove();
    state = false;
  }
}

final sampleDataLoadedProvider = NotifierProvider<SampleDataLoaded, bool>(
  SampleDataLoaded.new,
);

/// Adds the sample set and confirms with a snack bar.
Future<void> addSampleData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await ref.read(sampleDataLoadedProvider.notifier).add();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Settings row: add or remove the sample leads, clients and activities.
class SampleDataTile extends ConsumerStatefulWidget {
  const SampleDataTile({super.key});

  @override
  ConsumerState<SampleDataTile> createState() => _SampleDataTileState();
}

class _SampleDataTileState extends ConsumerState<SampleDataTile> {
  var _busy = false;

  Future<void> _toggle(bool loaded) async {
    if (loaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove sample data?'),
          content: const Text(
            'The sample leads, clients and activities are removed. Anything '
            'you added yourself stays.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('sample-remove-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      if (loaded) {
        await ref.read(sampleDataLoadedProvider.notifier).remove();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Sample data removed.')),
            );
        }
      } else if (mounted) {
        await addSampleData(context, ref);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(sampleDataLoadedProvider);
    return ListTile(
      key: const Key('sample-data'),
      leading: const Icon(Icons.science_outlined),
      title: Text(loaded ? 'Remove sample data' : 'Add sample data'),
      subtitle: Text(
        loaded
            ? 'Sample leads, clients and activities are in the app'
            : '40 leads, 18 clients with purchases, and 30 activities',
      ),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(loaded ? Icons.delete_outline_rounded : Icons.add_rounded),
      onTap: _busy ? null : () => _toggle(loaded),
    );
  }
}
