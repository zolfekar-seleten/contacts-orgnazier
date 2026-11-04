import 'package:country_contacts/features/templates/domain/saved_template.dart';
import 'package:country_contacts/features/templates/presentation/templates_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fixtures.dart';

void main() {
  Future<ProviderContainer> container([
    Map<String, Object> prefs = const {},
  ]) async {
    final c = ProviderContainer(
      overrides: await testOverrides(
        repository: FakeContactsRepository(),
        prefs: prefs,
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('starts with the starter templates', () async {
    final c = await container();
    expect(c.read(savedTemplatesProvider).map((t) => t.title), [
      'Greeting',
      'Eid greeting',
      'Meeting reminder',
    ]);
  });

  test('saved and deleted templates persist', () async {
    final c = await container();
    final templates = c.read(savedTemplatesProvider.notifier);
    await templates.add('  Ramadan  ', ' Ramadan Kareem, {first_name}! ');
    await templates.remove('starter-greeting');

    expect(c.read(savedTemplatesProvider).map((t) => t.title), [
      'Eid greeting',
      'Meeting reminder',
      'Ramadan',
    ]);
    expect(
      c.read(savedTemplatesProvider).last.body,
      'Ramadan Kareem, {first_name}!',
    );

    // A fresh app start reads them back.
    final prefs = await SharedPreferences.getInstance();
    final reloaded = await container({
      'saved_templates': prefs.getString('saved_templates')!,
    });
    expect(reloaded.read(savedTemplatesProvider).map((t) => t.title), [
      'Eid greeting',
      'Meeting reminder',
      'Ramadan',
    ]);
  });

  test('an emptied list stays empty instead of restoring starters', () async {
    final c = await container();
    for (final t in SavedTemplate.starters) {
      await c.read(savedTemplatesProvider.notifier).remove(t.id);
    }
    final prefs = await SharedPreferences.getInstance();
    final reloaded = await container({
      'saved_templates': prefs.getString('saved_templates')!,
    });
    expect(reloaded.read(savedTemplatesProvider), isEmpty);
  });
}
