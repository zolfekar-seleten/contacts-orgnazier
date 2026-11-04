import '../../contacts/domain/app_contact.dart';

enum ContactSort {
  firstName('First name'),
  lastName('Last name'),
  recentlyAdded('Recently added');

  const ContactSort(this.label);
  final String label;
}

enum NumberFilter {
  all('All'),
  mobile('Mobile'),
  landline('Landline');

  const NumberFilter(this.label);
  final String label;
}

class ContactListOptions {
  const ContactListOptions({
    this.sort = ContactSort.firstName,
    this.filter = NumberFilter.all,
  });

  final ContactSort sort;
  final NumberFilter filter;

  ContactListOptions copyWith({ContactSort? sort, NumberFilter? filter}) =>
      ContactListOptions(
        sort: sort ?? this.sort,
        filter: filter ?? this.filter,
      );
}

/// Whether [contact] has a number in [countryKey] of the filtered kind.
/// Landline means any classified number that numbering-plan metadata does
/// not mark as mobile.
bool matchesNumberFilter(
  AppContact contact,
  String countryKey,
  NumberFilter filter,
) => switch (filter) {
  NumberFilter.all => true,
  NumberFilter.mobile => contact.phonesFor(countryKey).any((p) => p.isMobile),
  NumberFilter.landline =>
    contact
        .phonesFor(countryKey)
        .any((p) => !p.isMobile && p.classification.isClassified),
};

/// Filters and sorts [contacts]. [firstSeen] maps contact IDs to when the
/// app first saw them (milliseconds since epoch; 0 for contacts that existed
/// before the app was installed).
List<AppContact> applyListOptions(
  List<AppContact> contacts, {
  required String countryKey,
  required ContactListOptions options,
  Map<String, int> firstSeen = const {},
}) {
  int byName(AppContact a, AppContact b) =>
      a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  String lastKey(AppContact c) =>
      (c.lastName.isEmpty ? c.displayName : c.lastName).toLowerCase();

  final result = [
    for (final c in contacts)
      if (matchesNumberFilter(c, countryKey, options.filter)) c,
  ];
  switch (options.sort) {
    case ContactSort.firstName:
      result.sort(byName);
    case ContactSort.lastName:
      result.sort((a, b) {
        final byLast = lastKey(a).compareTo(lastKey(b));
        return byLast != 0 ? byLast : byName(a, b);
      });
    case ContactSort.recentlyAdded:
      result.sort((a, b) {
        final byDate = (firstSeen[b.id] ?? 0).compareTo(firstSeen[a.id] ?? 0);
        return byDate != 0 ? byDate : byName(a, b);
      });
  }
  return result;
}
