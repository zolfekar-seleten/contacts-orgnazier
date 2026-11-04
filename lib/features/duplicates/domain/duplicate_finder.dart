import '../../contacts/domain/app_contact.dart';
import '../../contacts/domain/phone_classifier.dart';

enum DuplicateReason { samePhone, sameName }

/// Two or more contacts that share a phone number or an identical name.
class DuplicateGroup {
  const DuplicateGroup({
    required this.reason,
    required this.key,
    required this.contacts,
    this.phone,
  });

  final DuplicateReason reason;

  /// E.164 / normalized digits for [DuplicateReason.samePhone], the
  /// normalized name for [DuplicateReason.sameName].
  final String key;

  /// Sorted by name.
  final List<AppContact> contacts;

  /// One of the shared numbers, for display ([DuplicateReason.samePhone]).
  final ClassifiedPhone? phone;

  String get title => switch (reason) {
    DuplicateReason.samePhone => phone!.display,
    DuplicateReason.sameName => contacts.first.displayName,
  };

  /// Copies beyond the first contact in this group.
  int get extraCopies => contacts.length - 1;
}

class DuplicateReport {
  DuplicateReport({required this.groups});

  static final empty = DuplicateReport(groups: const []);

  /// Same-number groups first (largest first), then same-name groups.
  final List<DuplicateGroup> groups;

  Iterable<DuplicateGroup> get byPhone =>
      groups.where((g) => g.reason == DuplicateReason.samePhone);
  Iterable<DuplicateGroup> get byName =>
      groups.where((g) => g.reason == DuplicateReason.sameName);

  /// Distinct contacts that appear in at least one group.
  late final int contactCount = {
    for (final g in groups)
      for (final c in g.contacts) c.id,
  }.length;

  bool get isEmpty => groups.isEmpty;
}

/// Shorter digit strings are usually service codes, not personal numbers.
const _minDigits = 6;

/// Finds contacts that share a phone number or have an identical name.
///
/// Numbers match on E.164 when classified, otherwise on their digits. Names
/// match case- and whitespace-insensitively, and only when they contain
/// letters (a number saved as the name is not a name). A name group with the
/// same contacts as a phone group is dropped as redundant.
DuplicateReport findDuplicates(List<AppContact> contacts) {
  final byPhone = <String, List<(AppContact, ClassifiedPhone)>>{};
  final byName = <String, List<AppContact>>{};

  for (final contact in contacts) {
    final seenKeys = <String>{};
    for (final phone in contact.phones) {
      final key = phone.e164 ?? normalizePhoneInput(phone.raw);
      if (key.replaceAll('+', '').length < _minDigits) continue;
      if (seenKeys.add(key)) (byPhone[key] ??= []).add((contact, phone));
    }
    final name = _nameKey(contact.displayName);
    if (name != null) (byName[name] ??= []).add(contact);
  }

  int byDisplayName(AppContact a, AppContact b) =>
      a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  String idsOf(List<AppContact> cs) =>
      (cs.map((c) => c.id).toList()..sort()).join('\u0000');

  final phoneGroups = [
    for (final MapEntry(:key, :value) in byPhone.entries)
      if (value.length > 1)
        DuplicateGroup(
          reason: DuplicateReason.samePhone,
          key: key,
          phone: value.first.$2,
          contacts: [for (final (c, _) in value) c]..sort(byDisplayName),
        ),
  ];
  final phoneSets = {for (final g in phoneGroups) idsOf(g.contacts)};
  final nameGroups = [
    for (final MapEntry(:key, :value) in byName.entries)
      if (value.length > 1 && !phoneSets.contains(idsOf(value)))
        DuplicateGroup(
          reason: DuplicateReason.sameName,
          key: key,
          contacts: [...value]..sort(byDisplayName),
        ),
  ];

  int bySize(DuplicateGroup a, DuplicateGroup b) {
    final bySize = b.contacts.length.compareTo(a.contacts.length);
    return bySize != 0 ? bySize : a.title.compareTo(b.title);
  }

  return DuplicateReport(
    groups: [...phoneGroups..sort(bySize), ...nameGroups..sort(bySize)],
  );
}

String? _nameKey(String name) {
  final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return RegExp(r'\p{L}', unicode: true).hasMatch(key) ? key : null;
}
