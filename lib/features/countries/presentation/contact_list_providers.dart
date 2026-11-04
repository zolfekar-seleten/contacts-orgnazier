import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../contacts/data/first_seen_store.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/contact_list_options.dart';

/// Sort and number-type filter for country contact lists, shared by all
/// countries for the session.
class ContactListOptionsController extends Notifier<ContactListOptions> {
  @override
  ContactListOptions build() => const ContactListOptions();

  void setSort(ContactSort sort) => state = state.copyWith(sort: sort);
  void setFilter(NumberFilter filter) => state = state.copyWith(filter: filter);
}

final contactListOptionsProvider =
    NotifierProvider<ContactListOptionsController, ContactListOptions>(
      ContactListOptionsController.new,
    );

final firstSeenStoreProvider = Provider(
  (ref) => FirstSeenStore(ref.watch(sharedPreferencesProvider)),
);

/// When each loaded contact was first seen; updated on every reload.
final firstSeenProvider = Provider<Map<String, int>>((ref) {
  final directory = ref.watch(directoryProvider);
  if (directory == null) return const {};
  return ref
      .watch(firstSeenStoreProvider)
      .sync(directory.contacts.map((c) => c.id), ref.read(clockProvider)());
});
