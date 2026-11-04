import 'dart:async';

import 'package:country_contacts/core/clock.dart';
import 'package:country_contacts/features/communication/domain/communication_service.dart';
import 'package:country_contacts/features/communication/presentation/communication_providers.dart';
import 'package:country_contacts/features/contacts/domain/contacts_repository.dart';
import 'package:country_contacts/features/contacts/domain/device_contact.dart';
import 'package:country_contacts/features/contacts/presentation/contacts_providers.dart';
import 'package:country_contacts/features/settings/presentation/settings_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

DeviceContact contact(String id, String name, List<String> numbers) =>
    DeviceContact(
      id: id,
      displayName: name,
      phones: [
        for (final n in numbers) DevicePhone(number: n, label: 'Mobile'),
      ],
    );

final sampleContacts = [
  contact('1', 'Oliver Bennett', ['+44 7400 123456']),
  contact('2', 'Amelia Clarke', ['+44 20 7946 0958', '+44 7400 654321']),
  contact('3', 'James Miller', ['+1 650-253-0000']),
  contact('4', 'Emily Johnson', ['+1 415 555 2671', '+44 7400 222333']),
  contact('5', 'Ahmed Al Mansoori', ['+971 50 123 4567']),
  contact('6', 'Priya Sharma', ['+91 98765 43210']),
  contact('7', 'Mystery Number', ['12345']),
];

class FakeContactsRepository implements ContactsRepository {
  FakeContactsRepository({
    this.status = ContactsPermission.granted,
    this.statusAfterRequest = ContactsPermission.granted,
    List<DeviceContact>? contacts,
    this.error,
  }) : contacts = contacts ?? sampleContacts;

  ContactsPermission status;
  ContactsPermission statusAfterRequest;
  List<DeviceContact> contacts;
  Object? error;
  int fetchCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;
  final _changes = StreamController<void>.broadcast();

  void emitChange() => _changes.add(null);

  @override
  Future<ContactsPermission> checkPermission() async => status;

  @override
  Future<ContactsPermission> requestPermission() async {
    requestCount++;
    return status = statusAfterRequest;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCount++;

  @override
  Future<List<DeviceContact>> fetchContacts() async {
    fetchCount++;
    if (error != null) throw error!;
    return contacts;
  }

  ContactEditResult editResult = ContactEditResult.saved;
  final editedIds = <String>[];

  /// Applied to [contacts] when the fake editor "saves".
  List<DeviceContact>? contactsAfterEdit;

  @override
  Future<ContactEditResult> openSystemEditor(String contactId) async {
    editedIds.add(contactId);
    if (editResult == ContactEditResult.saved && contactsAfterEdit != null) {
      contacts = contactsAfterEdit!;
    }
    return editResult;
  }

  @override
  Stream<void> get changes => _changes.stream;
}

class MockUrlLauncher extends Mock implements UrlLauncherGateway {}

void registerFallbacks() => registerFallbackValue(Uri());

/// Daytime in the sample contacts' main countries (UK 13:00, New York 08:00,
/// UAE 16:00, India 17:30), so no late-night prompts appear unless a test
/// asks for them.
final middayUtc = DateTime.utc(2026, 6, 15, 12);

/// Provider overrides for a fully faked app.
Future<List<Override>> testOverrides({
  required ContactsRepository repository,
  UrlLauncherGateway? launcher,
  String? deviceRegion = 'GB',
  Map<String, Object> prefs = const {},
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(instance),
    deviceRegionProvider.overrideWithValue(deviceRegion),
    contactsRepositoryProvider.overrideWithValue(repository),
    clockProvider.overrideWithValue(() => now ?? middayUtc),
    if (launcher != null) urlLauncherProvider.overrideWithValue(launcher),
  ];
}
