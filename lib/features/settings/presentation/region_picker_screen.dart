import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flag_badge.dart';
import '../../../core/widgets/search_field.dart';
import '../../contact_search/domain/contact_search_index.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../../countries/domain/country.dart';

const _regionSearchScope = 'region-picker';

final _regionResultsProvider = Provider.autoDispose<List<Country>>((ref) {
  final q = ref.watch(searchQueryProvider(_regionSearchScope)).toLowerCase();
  if (q.isEmpty) return Country.all;
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  return Country.all
      .where(
        (c) =>
            ContactSearchIndex.matchesCountry(c, q) ||
            (digits.isNotEmpty && c.dialCode.startsWith(digits)),
      )
      .toList();
});

/// Searchable list of all regions. Pops with the chosen [Country].
class RegionPickerScreen extends ConsumerWidget {
  const RegionPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(_regionResultsProvider);
    final padding = contentPadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose region')),
      body: Column(
        children: [
          Padding(
            padding: padding.copyWith(top: 4, bottom: 8),
            child: SearchField(
              hint: 'Search country or code',
              onChanged: ref
                  .read(searchQueryProvider(_regionSearchScope).notifier)
                  .update,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: padding.copyWith(bottom: 24),
              itemCount: countries.length,
              itemExtent: 64,
              itemBuilder: (context, i) {
                final c = countries[i];
                return ListTile(
                  leading: FlagBadge(country: c, size: 36),
                  title: Text(c.name),
                  trailing: Text(c.formattedDialCode),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
