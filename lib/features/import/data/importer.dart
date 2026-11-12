import 'package:drift/drift.dart' show Value;

import '../../crm/data/crm_database.dart';
import '../../crm/data/crm_repository.dart';
import '../../crm/presentation/crm_widgets.dart' show statusPalette;
import '../domain/import_plan.dart';

/// Saves an [ImportPlan]: adds statuses named in the sheet that don't exist
/// yet, then inserts every ready row. Returns how many were added.
Future<int> runImport(
  CrmRepository repo,
  ImportPlan plan, {
  required PartyKind kind,
  required List<LeadStatus> statuses,
}) async {
  final ids = {for (final s in statuses) s.name.toLowerCase(): s.id};
  if (kind == PartyKind.lead) {
    for (final (i, name) in plan.newStatuses.indexed) {
      final color = statusPalette[(statuses.length + i) % statusPalette.length];
      ids[name.toLowerCase()] = await repo.addStatus(name, color);
    }
  }
  final defaultStatus = statuses.firstOrNull?.id;
  final rows = [
    for (final r in plan.ready)
      r.data!.copyWith(
        statusId: Value(
          kind == PartyKind.lead
              ? ids[r.statusName?.toLowerCase()] ?? defaultStatus
              : null,
        ),
      ),
  ];
  await repo.insertParties(rows);
  return rows.length;
}
