import 'dart:typed_data';

/// A phone number exactly as stored on the device.
class DevicePhone {
  const DevicePhone({
    required this.number,
    this.platformNormalized,
    this.label = '',
  });

  final String number;

  /// E.164 normalization supplied by the OS (Android only), if any.
  final String? platformNormalized;
  final String label;
}

/// Read-only snapshot of a device contact. The original contact is never
/// modified.
class DeviceContact {
  const DeviceContact({
    required this.id,
    required this.displayName,
    required this.phones,
    this.thumbnail,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String displayName;

  /// Structured name parts from the address book, when available.
  final String? firstName;
  final String? lastName;
  final List<DevicePhone> phones;
  final Uint8List? thumbnail;
}
