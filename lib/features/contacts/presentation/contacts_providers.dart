import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_providers.dart';
import '../data/device_contacts_repository.dart';
import '../domain/app_contact.dart';
import '../domain/contact_directory.dart';
import '../domain/contacts_repository.dart';
import '../domain/device_contact.dart';
import '../domain/phone_classifier.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => const DeviceContactsRepository(),
);

/// Rebuilt only when the effective region changes, so its in-memory cache of
/// classifications survives contact reloads.
final phoneClassifierProvider = Provider<PhoneClassifier>(
  (ref) => PhoneClassifier(defaultRegion: ref.watch(effectiveRegionProvider)),
);

/// Permission state plus the raw device contacts.
sealed class ContactsAccess {
  const ContactsAccess();
}

final class AccessRequired extends ContactsAccess {
  const AccessRequired(this.status);
  final ContactsPermission status;
}

final class AccessGranted extends ContactsAccess {
  const AccessGranted(this.contacts);
  final List<DeviceContact> contacts;
}

class ContactsController extends AsyncNotifier<ContactsAccess> {
  Timer? _changeDebounce;

  ContactsRepository get _repo => ref.read(contactsRepositoryProvider);

  @override
  Future<ContactsAccess> build() async {
    final repo = ref.watch(contactsRepositoryProvider);
    final changes = repo.changes.listen((_) {
      _changeDebounce?.cancel();
      _changeDebounce = Timer(const Duration(milliseconds: 500), refresh);
    }, onError: (_) {});
    // Re-check after returning from system Settings.
    final lifecycle = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(() {
      changes.cancel();
      lifecycle.dispose();
      _changeDebounce?.cancel();
    });

    final status = await repo.checkPermission();
    if (!status.canRead) return AccessRequired(status);
    return AccessGranted(await repo.fetchContacts());
  }

  /// Shows the OS prompt. Only called from the rationale screen.
  Future<void> requestAccess() async {
    final status = await _repo.requestPermission();
    if (!ref.mounted) return;
    if (!status.canRead) {
      state = AsyncData(AccessRequired(status));
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => AccessGranted(await _repo.fetchContacts()),
    );
  }

  /// Reloads contacts while keeping the current data on screen.
  Future<void> refresh() async {
    if (state.value is! AccessGranted) return;
    final next = await AsyncValue.guard(
      () async => AccessGranted(await _repo.fetchContacts()),
    );
    if (ref.mounted) state = next;
  }

  Future<void> openSettings() => _repo.openAppSettings();

  /// Hands the contact to the system editor and reloads if the user saved.
  Future<ContactEditResult> editInSystemApp(String contactId) async {
    final result = await _repo.openSystemEditor(contactId);
    if (result == ContactEditResult.saved) await refresh();
    return result;
  }

  Future<void> _onResume() async {
    if (state.value case AccessRequired()) {
      final status = await _repo.checkPermission();
      if (status.canRead && ref.mounted) ref.invalidateSelf();
    }
  }
}

final contactsControllerProvider =
    AsyncNotifierProvider<ContactsController, ContactsAccess>(
      ContactsController.new,
      retry: (_, _) => null,
    );

/// What the main screen renders.
sealed class ContactsView {
  const ContactsView();
}

final class NeedsPermission extends ContactsView {
  const NeedsPermission(this.status);
  final ContactsPermission status;
}

final class ContactsReady extends ContactsView {
  const ContactsReady(this.directory);
  final ContactDirectory directory;
}

final contactsViewProvider = FutureProvider<ContactsView>((ref) async {
  final accessFuture = ref.watch(contactsControllerProvider.future);
  final classifier = ref.watch(phoneClassifierProvider);
  switch (await accessFuture) {
    case AccessRequired(:final status):
      return NeedsPermission(status);
    case AccessGranted(:final contacts):
      await precomputeClassifications(contacts, classifier);
      return ContactsReady(ContactDirectory.build(contacts, classifier));
  }
}, retry: (_, _) => null);

/// The loaded directory, or null while loading / without permission.
final directoryProvider = Provider<ContactDirectory?>((ref) {
  final view = ref.watch(contactsViewProvider).value;
  return view is ContactsReady ? view.directory : null;
});

final contactByIdProvider = Provider.family<AppContact?, String>(
  (ref, id) => ref.watch(directoryProvider)?.contactById(id),
);

final countryGroupProvider = Provider.family<CountryGroup?, String>(
  (ref, key) => ref.watch(directoryProvider)?.group(key),
);
