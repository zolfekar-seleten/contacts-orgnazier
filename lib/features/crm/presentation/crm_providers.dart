import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../contact_search/presentation/search_providers.dart';
import '../data/activity_repository.dart';
import '../data/attachment_store.dart';
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

// Activities ---------------------------------------------------------------

final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(
    ref.watch(crmDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Overridden in tests with a temporary folder.
final attachmentStoreProvider = Provider((ref) => AttachmentStore());

final imageSourceProvider = Provider<ImageSourceGateway>(
  (ref) => ImagePickerGateway(),
);

/// All activities, or one lead's or client's when given a party id.
final activitiesProvider = StreamProvider.family<List<Activity>, String?>(
  (ref, partyId) =>
      ref.watch(activityRepositoryProvider).watchActivities(partyId: partyId),
);

final activityProvider = StreamProvider.autoDispose.family<Activity?, String>(
  (ref, id) => ref.watch(activityRepositoryProvider).watchActivity(id),
);

final attachmentCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(activityRepositoryProvider).watchAttachmentCounts(),
);

final attachmentsProvider = StreamProvider.autoDispose
    .family<List<ActivityAttachment>, String>(
      (ref, id) => ref.watch(activityRepositoryProvider).watchAttachments(id),
    );

/// Every lead and client by id, for showing who an activity is with.
final partiesByIdProvider = Provider<Map<String, Party>>((ref) {
  final leads = ref.watch(partiesProvider(PartyKind.lead)).value ?? const [];
  final clients =
      ref.watch(partiesProvider(PartyKind.client)).value ?? const [];
  return {
    for (final p in [...leads, ...clients]) p.id: p,
  };
});
