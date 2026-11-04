import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_view.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../../contacts/domain/app_contact.dart';
import '../../contacts/presentation/contacts_providers.dart';
import 'country_tile.dart';

const countrySearchScope = 'countries';

/// Countries with contacts matching the query (name, ISO code or dialing
/// code), plus the Unknown bucket when it matches.
final countrySearchProvider = Provider.autoDispose<List<CountryGroup>>((ref) {
  final query = ref.watch(searchQueryProvider(countrySearchScope));
  final index = ref.watch(searchIndexProvider);
  if (index == null) return const [];
  final q = query.toLowerCase();
  final unknown = index.directory.unknown;
  final showUnknown =
      unknown.count > 0 &&
      (q.isEmpty || 'unknown'.contains(q) || 'uncategorised'.contains(q));
  return [...index.searchCountries(query), if (showUnknown) unknown];
});

/// Jump straight to a country instead of scrolling the full list.
class CountrySearchScreen extends ConsumerWidget {
  const CountrySearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = contentPadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Find a country')),
      body: Column(
        children: [
          Padding(
            padding: padding.copyWith(top: 4, bottom: 8),
            child: SearchField(
              autofocus: true,
              hint: 'Country name, code or +dial code',
              onChanged: ref
                  .read(searchQueryProvider(countrySearchScope).notifier)
                  .update,
            ),
          ),
          const Expanded(child: _Results()),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(countrySearchProvider);
    final total = ref.watch(
      directoryProvider.select((d) => d?.totalContacts ?? 0),
    );
    if (groups.isEmpty) {
      return const StateView(
        icon: Icons.travel_explore_rounded,
        title: 'No matching country',
        message: 'None of your contacts are in a country matching that search.',
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: contentPadding(context).copyWith(top: 8, bottom: 32),
      itemCount: groups.length,
      itemBuilder: (context, i) => GroupedListItem(
        key: ValueKey(groups[i].key),
        index: i,
        count: groups.length,
        child: CountryTile(group: groups[i], total: total),
      ),
    );
  }
}
