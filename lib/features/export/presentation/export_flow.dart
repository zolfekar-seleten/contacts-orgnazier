import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../broadcast/presentation/broadcast_providers.dart';
import '../../contacts/domain/app_contact.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../countries/domain/country.dart';
import '../data/file_sharer.dart';
import '../domain/csv_export.dart';

/// Exports the selected contacts' numbers from [countryKey] as a CSV file
/// through the share sheet, then reports the outcome.
Future<void> exportSelectionToCsv(
  BuildContext context,
  WidgetRef ref, {
  required String countryKey,
}) async {
  final directory = ref.read(directoryProvider);
  if (directory == null) return;
  final contacts =
      [
        for (final id in ref.read(selectionProvider).ids)
          if (directory.contactById(id) case final c?) c,
      ]..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  final numbers = contacts.fold(
    0,
    (n, c) => n + c.phonesFor(countryKey).length,
  );
  final scope = countryKey == CountryGroup.unknownKey
      ? 'Unknown country'
      : Country.fromIso(countryKey)?.name ?? countryKey;

  // iPad anchors the share popover to the tapped button.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.of(context);

  try {
    final shared = await ref
        .read(fileSharerProvider)
        .shareText(
          fileName: csvFileName(scope, DateTime.now()),
          contents: contactsToCsv(contacts, countryKey: countryKey),
          mimeType: 'text/csv',
          origin: origin,
        );
    if (!shared) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Exported $numbers ${numbers == 1 ? 'number' : 'numbers'} '
            'to CSV.',
          ),
        ),
      );
  } on Exception {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Couldn’t export.')));
  }
}
