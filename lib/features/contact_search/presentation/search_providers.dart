import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/domain/app_contact.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../countries/domain/contact_list_options.dart';
import '../../countries/presentation/contact_list_providers.dart';
import '../domain/contact_search_index.dart';

/// Scope for the home screen's search. Country screens use their country key.
const globalSearchScope = '*';

/// Debounced search text for a given scope.
class SearchQueryController extends Notifier<String> {
  SearchQueryController(this.scope);

  final String scope;
  static const debounce = Duration(milliseconds: 200);
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void update(String text) {
    _timer?.cancel();
    if (text.trim().isEmpty) {
      state = '';
      return;
    }
    _timer = Timer(debounce, () => state = text.trim());
  }
}

final searchQueryProvider = NotifierProvider.autoDispose
    .family<SearchQueryController, String, String>(SearchQueryController.new);

/// Built once per loaded directory.
final searchIndexProvider = Provider<ContactSearchIndex?>((ref) {
  final directory = ref.watch(directoryProvider);
  return directory == null ? null : ContactSearchIndex(directory);
});

typedef GlobalSearchResults = ({
  List<CountryGroup> countries,
  List<AppContact> contacts,
});

/// Results for the home screen search, or null when the query is empty.
final globalSearchProvider = Provider.autoDispose<GlobalSearchResults?>((ref) {
  final query = ref.watch(searchQueryProvider(globalSearchScope));
  final index = ref.watch(searchIndexProvider);
  if (query.isEmpty || index == null) return null;
  return (
    countries: index.searchCountries(query),
    contacts: index.searchContacts(query),
  );
});

/// Contacts of one country (or Unknown) matching that screen's query, before
/// the number-type filter and sort.
final countrySearchResultsProvider = Provider.autoDispose
    .family<List<AppContact>, String>((ref, countryKey) {
      final query = ref.watch(searchQueryProvider(countryKey));
      final index = ref.watch(searchIndexProvider);
      if (index == null) return const [];
      return index.searchContacts(query, countryKey: countryKey);
    });

/// What a country screen lists: search results, filtered and sorted.
final countryContactsProvider = Provider.autoDispose
    .family<List<AppContact>, String>((ref, countryKey) {
      final options = ref.watch(contactListOptionsProvider);
      return applyListOptions(
        ref.watch(countrySearchResultsProvider(countryKey)),
        countryKey: countryKey,
        options: options,
        firstSeen: options.sort == ContactSort.recentlyAdded
            ? ref.watch(firstSeenProvider)
            : const {},
      );
    });

/// How many search results each number-type filter would show.
final numberFilterCountsProvider = Provider.autoDispose
    .family<Map<NumberFilter, int>, String>((ref, countryKey) {
      final results = ref.watch(countrySearchResultsProvider(countryKey));
      return {
        for (final f in NumberFilter.values)
          f: results.where((c) => matchesNumberFilter(c, countryKey, f)).length,
      };
    });
