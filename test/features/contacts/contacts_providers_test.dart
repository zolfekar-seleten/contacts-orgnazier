import 'package:country_contacts/features/contact_search/presentation/search_providers.dart';
import 'package:country_contacts/features/contacts/domain/contacts_repository.dart';
import 'package:country_contacts/features/contacts/presentation/contacts_providers.dart';
import 'package:country_contacts/features/settings/domain/app_settings.dart';
import 'package:country_contacts/features/settings/presentation/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer(
    FakeContactsRepository repo, {
    String? deviceRegion = 'GB',
  }) async {
    final container = ProviderContainer(
      overrides: await testOverrides(
        repository: repo,
        deviceRegion: deviceRegion,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('does not request permission on its own', () async {
    final repo = FakeContactsRepository(
      status: ContactsPermission.notDetermined,
    );
    final container = await makeContainer(repo);

    final view = await container.read(contactsViewProvider.future);

    expect(view, isA<NeedsPermission>());
    expect(repo.requestCount, 0);
    expect(repo.fetchCount, 0);
  });

  test('loads contacts after the user grants access', () async {
    final repo = FakeContactsRepository(
      status: ContactsPermission.notDetermined,
    );
    final container = await makeContainer(repo);
    await container.read(contactsViewProvider.future);

    await container.read(contactsControllerProvider.notifier).requestAccess();
    final view = await container.read(contactsViewProvider.future);

    expect(repo.requestCount, 1);
    expect((view as ContactsReady).directory.totalContacts, 7);
  });

  test('permanently denied is surfaced', () async {
    final repo = FakeContactsRepository(
      status: ContactsPermission.notDetermined,
      statusAfterRequest: ContactsPermission.permanentlyDenied,
    );
    final container = await makeContainer(repo);
    await container.read(contactsViewProvider.future);
    await container.read(contactsControllerProvider.notifier).requestAccess();

    final view = await container.read(contactsViewProvider.future);
    expect(
      (view as NeedsPermission).status,
      ContactsPermission.permanentlyDenied,
    );
  });

  test('load errors surface without automatic retries', () async {
    final repo = FakeContactsRepository(error: StateError('boom'));
    final container = await makeContainer(repo);
    final sub = container.listen(contactsViewProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(contactsViewProvider.future),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(repo.fetchCount, 1);
  });

  test('changing the region reclassifies without refetching', () async {
    final repo = FakeContactsRepository(
      contacts: [
        contact('1', 'Omar', ['050 765 4321']),
      ],
    );
    final container = await makeContainer(repo, deviceRegion: null);
    final sub = container.listen(contactsViewProvider, (_, _) {});
    addTearDown(sub.close);

    final before = await container.read(contactsViewProvider.future);
    expect((before as ContactsReady).directory.unknown.count, 1);

    container
        .read(settingsProvider.notifier)
        .setRegion(const ManualRegion('AE'));
    final after = await container.read(contactsViewProvider.future);

    expect((after as ContactsReady).directory.group('AE')?.count, 1);
    expect(repo.fetchCount, 1);
  });

  test('address book changes trigger a debounced refresh', () async {
    final repo = FakeContactsRepository();
    final container = await makeContainer(repo);
    final sub = container.listen(contactsViewProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(contactsViewProvider.future);

    repo.contacts = [
      ...repo.contacts,
      contact('8', 'New', ['+33 6 12 34 56 78']),
    ];
    repo
      ..emitChange()
      ..emitChange();
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(repo.fetchCount, 2);
    final view = await container.read(contactsViewProvider.future);
    expect((view as ContactsReady).directory.group('FR')?.count, 1);
  });

  test('search query is debounced', () async {
    final container = await makeContainer(FakeContactsRepository());
    final sub = container.listen(globalSearchProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(contactsViewProvider.future);

    final notifier = container.read(
      searchQueryProvider(globalSearchScope).notifier,
    );
    notifier
      ..update('ol')
      ..update('oli');
    expect(container.read(globalSearchProvider), isNull);

    await Future<void>.delayed(
      SearchQueryController.debounce + const Duration(milliseconds: 50),
    );
    expect(
      container.read(globalSearchProvider)!.contacts.single.displayName,
      'Oliver Bennett',
    );
  });

  test('settings persist and effective region follows preference', () async {
    final container = await makeContainer(FakeContactsRepository());
    expect(container.read(effectiveRegionProvider), 'GB');

    container.read(settingsProvider.notifier).setRegion(RegionPreference.none);
    expect(container.read(effectiveRegionProvider), isNull);
    expect(
      container.read(sharedPreferencesProvider).getString('default_region'),
      'none',
    );
  });
}
