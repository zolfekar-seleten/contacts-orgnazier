import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_contacts/flutter_contacts.dart';

import '../domain/contacts_repository.dart';
import '../domain/device_contact.dart';

class DeviceContactsRepository implements ContactsRepository {
  const DeviceContactsRepository();

  @override
  Future<ContactsPermission> checkPermission() async =>
      _map(await FlutterContacts.permissions.check(PermissionType.read));

  @override
  Future<ContactsPermission> requestPermission() async =>
      _map(await FlutterContacts.permissions.request(PermissionType.read));

  @override
  Future<void> openAppSettings() => FlutterContacts.permissions.openSettings();

  @override
  Future<List<DeviceContact>> fetchContacts() async {
    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.photoThumbnail,
      },
    );
    return [
      for (final c in contacts)
        if (c.id != null && c.phones.isNotEmpty)
          DeviceContact(
            id: c.id!,
            displayName: c.displayName ?? '',
            firstName: c.name?.first,
            lastName: c.name?.last,
            thumbnail: c.photo?.thumbnail,
            phones: [
              for (final p in c.phones)
                DevicePhone(
                  number: p.number,
                  platformNormalized: p.normalizedNumber,
                  label: p.label.customLabel ?? _labelName(p.label.label),
                ),
            ],
          ),
    ];
  }

  @override
  Future<ContactEditResult> openSystemEditor(String contactId) async {
    try {
      final savedId = await FlutterContacts.native.showEditor(contactId);
      return savedId == null
          ? ContactEditResult.cancelled
          : ContactEditResult.saved;
    } on PlatformException {
      return ContactEditResult.unavailable;
    }
  }

  @override
  Stream<void> get changes => FlutterContacts.onDatabaseChange;

  static String _labelName(PhoneLabel label) => switch (label) {
    PhoneLabel.mobile => 'Mobile',
    PhoneLabel.home => 'Home',
    PhoneLabel.work => 'Work',
    PhoneLabel.main => 'Main',
    PhoneLabel.iPhone => 'iPhone',
    PhoneLabel.other => 'Other',
    _ => label.name[0].toUpperCase() + label.name.substring(1),
  };

  static ContactsPermission _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted => ContactsPermission.granted,
    PermissionStatus.limited => ContactsPermission.limited,
    PermissionStatus.denied => ContactsPermission.denied,
    PermissionStatus.permanentlyDenied => ContactsPermission.permanentlyDenied,
    PermissionStatus.restricted => ContactsPermission.restricted,
    PermissionStatus.notDetermined => ContactsPermission.notDetermined,
  };
}
