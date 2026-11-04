import 'device_contact.dart';

enum ContactsPermission {
  granted,
  limited,
  notDetermined,
  denied,
  permanentlyDenied,
  restricted;

  bool get canRead => this == granted || this == limited;
}

/// Outcome of handing a contact to the system contacts editor.
enum ContactEditResult { saved, cancelled, unavailable }

/// Read-only access to the device address book. Implementations must never
/// modify, delete or upload contacts themselves; edits happen only in the
/// system editor, saved by the user.
abstract interface class ContactsRepository {
  Future<ContactsPermission> checkPermission();

  /// Shows the OS permission prompt. Call only after explaining why.
  Future<ContactsPermission> requestPermission();

  Future<void> openAppSettings();

  Future<List<DeviceContact>> fetchContacts();

  /// Opens the OS contacts app's editor for [contactId].
  Future<ContactEditResult> openSystemEditor(String contactId);

  /// Emits when the device address book changes.
  Stream<void> get changes;
}
