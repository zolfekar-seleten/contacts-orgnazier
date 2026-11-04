import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/templates_repository.dart';
import '../domain/saved_template.dart';

final templatesRepositoryProvider = Provider(
  (ref) => TemplatesRepository(ref.watch(sharedPreferencesProvider)),
);

class SavedTemplatesController extends Notifier<List<SavedTemplate>> {
  TemplatesRepository get _repo => ref.read(templatesRepositoryProvider);

  @override
  List<SavedTemplate> build() => ref.watch(templatesRepositoryProvider).load();

  Future<void> add(String title, String body) {
    final id = 't${ref.read(clockProvider)().microsecondsSinceEpoch}';
    return _set([
      ...state,
      SavedTemplate(id: id, title: title.trim(), body: body.trim()),
    ]);
  }

  Future<void> remove(String id) => _set([
    for (final t in state)
      if (t.id != id) t,
  ]);

  Future<void> _set(List<SavedTemplate> templates) {
    state = templates;
    return _repo.save(templates);
  }
}

final savedTemplatesProvider =
    NotifierProvider<SavedTemplatesController, List<SavedTemplate>>(
      SavedTemplatesController.new,
    );
