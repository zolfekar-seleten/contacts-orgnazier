import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../data/crm_database.dart';
import '../data/crm_repository.dart';

/// The local SQLite database; overridden with an in-memory one in tests.
final crmDatabaseProvider = Provider<CrmDatabase>((ref) {
  final db = CrmDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final crmRepositoryProvider = Provider(
  (ref) => CrmRepository(
    ref.watch(crmDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final leadStatusesProvider = StreamProvider<List<LeadStatus>>(
  (ref) => ref.watch(crmRepositoryProvider).watchStatuses(),
);

final partiesProvider = StreamProvider.family<List<Party>, PartyKind>(
  (ref, kind) => ref.watch(crmRepositoryProvider).watchParties(kind),
);

final partyProvider = StreamProvider.autoDispose.family<Party?, String>(
  (ref, id) => ref.watch(crmRepositoryProvider).watchParty(id),
);

final dealsProvider = StreamProvider.autoDispose.family<List<Deal>, String>(
  (ref, partyId) => ref.watch(crmRepositoryProvider).watchDeals(partyId),
);

final sourceSuggestionsProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(crmRepositoryProvider).watchSources(),
);

final subSourceSuggestionsProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(crmRepositoryProvider).watchSubSources(),
);

/// Search scopes for the Leads and Clients tabs.
String partySearchScope(PartyKind kind) => 'crm-${kind.name}';

/// Lead status filter on the Leads tab; null shows every status.
class LeadStatusFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? statusId) => state = statusId;
}

final leadStatusFilterProvider = NotifierProvider<LeadStatusFilter, String?>(
  LeadStatusFilter.new,
);

/// The Leads or Clients list after search (and, for leads, status filter).
final visiblePartiesProvider = Provider.autoDispose
    .family<AsyncValue<List<Party>>, PartyKind>((ref, kind) {
      final query = ref
          .watch(searchQueryProvider(partySearchScope(kind)))
          .toLowerCase();
      final status = kind == PartyKind.lead
          ? ref.watch(leadStatusFilterProvider)
          : null;
      return ref
          .watch(partiesProvider(kind))
          .whenData(
            (parties) => [
              for (final p in parties)
                if ((status == null || p.statusId == status) &&
                    matchesPartyQuery(p, query))
                  p,
            ],
          );
    });

/// Name, mobile number, source or sub-source contains [query].
bool matchesPartyQuery(Party p, String query) {
  if (query.isEmpty) return true;
  final digits = query.replaceAll(RegExp(r'\D'), '');
  return p.name.toLowerCase().contains(query) ||
      (digits.isNotEmpty &&
          '${p.dialCode ?? ''}${p.mobile ?? ''}'.contains(digits)) ||
      (p.source?.toLowerCase().contains(query) ?? false) ||
      (p.subSource?.toLowerCase().contains(query) ?? false);
}
