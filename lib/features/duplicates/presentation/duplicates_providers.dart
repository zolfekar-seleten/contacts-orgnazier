import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/presentation/contacts_providers.dart';
import '../domain/duplicate_finder.dart';

/// Duplicates in the loaded directory; empty while loading.
final duplicatesProvider = Provider<DuplicateReport>((ref) {
  final directory = ref.watch(directoryProvider);
  return directory == null
      ? DuplicateReport.empty
      : findDuplicates(directory.contacts);
});
