import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../communication/domain/communication_service.dart';
import '../../communication/presentation/communication_providers.dart';
import '../../contacts/domain/app_contact.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../domain/broadcast.dart';

/// Multi-select state for contact lists.
class SelectionState {
  const SelectionState({this.active = false, this.ids = const {}});

  final bool active;
  final Set<String> ids;

  int get count => ids.length;
}

class SelectionController extends Notifier<SelectionState> {
  @override
  SelectionState build() => const SelectionState();

  void start([String? firstId]) =>
      state = SelectionState(active: true, ids: {...state.ids, ?firstId});

  void toggle(String id) {
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    state = SelectionState(active: true, ids: ids);
  }

  /// Selects all of [ids], or deselects them if all are already selected.
  void toggleAll(Iterable<String> ids) {
    final all = ids.toSet();
    final next = state.ids.containsAll(all)
        ? state.ids.difference(all)
        : {...state.ids, ...all};
    state = SelectionState(active: true, ids: next);
  }

  void exit() => state = const SelectionState();
}

final selectionProvider = NotifierProvider<SelectionController, SelectionState>(
  SelectionController.new,
);

/// Whether [id] is selected; lets each tile rebuild only for its own change.
final isSelectedProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(selectionProvider.select((s) => s.ids.contains(id))),
);

/// What the composer is preparing: who, from which country screen, and how.
class BroadcastDraft {
  const BroadcastDraft({
    required this.contactIds,
    this.countryKey,
    this.channel = BroadcastChannel.whatsApp,
  });

  final List<String> contactIds;
  final String? countryKey;
  final BroadcastChannel channel;

  BroadcastDraft copyWith({
    List<String>? contactIds,
    BroadcastChannel? channel,
  }) => BroadcastDraft(
    contactIds: contactIds ?? this.contactIds,
    countryKey: countryKey,
    channel: channel ?? this.channel,
  );
}

class BroadcastDraftController extends Notifier<BroadcastDraft> {
  @override
  BroadcastDraft build() => const BroadcastDraft(contactIds: []);

  void begin(Iterable<String> ids, {String? countryKey}) =>
      state = BroadcastDraft(contactIds: ids.toList(), countryKey: countryKey);

  void setChannel(BroadcastChannel channel) =>
      state = state.copyWith(channel: channel);

  void remove(String id) =>
      state = state.copyWith(contactIds: [...state.contactIds]..remove(id));
}

final broadcastDraftProvider =
    NotifierProvider<BroadcastDraftController, BroadcastDraft>(
      BroadcastDraftController.new,
    );

/// Draft recipients resolved against the current directory, in name order.
final draftContactsProvider = Provider<List<AppContact>>((ref) {
  final ids = ref.watch(broadcastDraftProvider.select((d) => d.contactIds));
  final directory = ref.watch(directoryProvider);
  if (directory == null) return const [];
  return [
    for (final id in ids)
      if (directory.contactById(id) case final c?) c,
  ]..sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
});

/// A running broadcast: one personalised chat opened at a time.
class BroadcastSession {
  const BroadcastSession({
    required this.channel,
    required this.items,
    this.index = 0,
  });

  final BroadcastChannel channel;
  final List<BroadcastItem> items;

  /// Item the next "Open" acts on; equals `items.length` when finished.
  final int index;

  bool get isFinished => index >= items.length;
  BroadcastItem? get current => isFinished ? null : items[index];
  int count(DeliveryStatus status) =>
      items.where((i) => i.status == status).length;

  BroadcastSession copyWith({List<BroadcastItem>? items, int? index}) =>
      BroadcastSession(
        channel: channel,
        items: items ?? this.items,
        index: index ?? this.index,
      );
}

/// Outcome of opening the current recipient, for UI feedback.
enum OpenOutcome { opened, whatsAppMissing, unsupported, failed }

class BroadcastController extends Notifier<BroadcastSession?> {
  @override
  BroadcastSession? build() => null;

  void start(BroadcastChannel channel, List<BroadcastItem> items) =>
      state = BroadcastSession(channel: channel, items: items);

  /// Opens WhatsApp / Messages for the current recipient with their message.
  /// The user sends it there; on success we move to the next recipient.
  Future<OpenOutcome> openCurrent({bool viaWeb = false}) async {
    final session = state;
    final item = session?.current;
    if (session == null || item == null) return OpenOutcome.failed;
    final service = ref.read(communicationServiceProvider);

    final OpenOutcome outcome;
    switch (session.channel) {
      case BroadcastChannel.whatsApp:
        final result = viaWeb
            ? await service.openWhatsAppWeb(
                item.phone.e164,
                message: item.message,
              )
            : await service.openWhatsApp(
                item.phone.e164,
                message: item.message,
              );
        outcome = switch (result) {
          WhatsAppResult.appOpened ||
          WhatsAppResult.webOpened => OpenOutcome.opened,
          WhatsAppResult.notInstalled => OpenOutcome.whatsAppMissing,
          WhatsAppResult.invalidNumber ||
          WhatsAppResult.failed => OpenOutcome.failed,
        };
      case BroadcastChannel.sms:
        final result = await service.openSms(
          item.phone.raw,
          e164: item.phone.e164,
          message: item.message,
        );
        outcome = switch (result) {
          SmsResult.composerOpened => OpenOutcome.opened,
          SmsResult.unsupported => OpenOutcome.unsupported,
          SmsResult.invalidNumber || SmsResult.failed => OpenOutcome.failed,
        };
    }
    if (!ref.mounted) return outcome;
    if (outcome == OpenOutcome.opened) {
      _mark(session.index, DeliveryStatus.opened, advance: true);
    } else if (outcome == OpenOutcome.failed) {
      _mark(session.index, DeliveryStatus.failed, advance: false);
    }
    return outcome;
  }

  void skipCurrent() {
    final session = state;
    if (session == null || session.isFinished) return;
    _mark(session.index, DeliveryStatus.skipped, advance: true);
  }

  /// Jump to any recipient, e.g. to retry one that was skipped.
  void jumpTo(int index) {
    final session = state;
    if (session == null || index < 0 || index >= session.items.length) return;
    state = session.copyWith(index: index);
  }

  void finish() => state = null;

  void _mark(int index, DeliveryStatus status, {required bool advance}) {
    final session = state!;
    final items = [...session.items];
    items[index] = items[index].withStatus(status);
    var next = session.index;
    if (advance) {
      // Next recipient still pending, or the end.
      next = items.indexWhere(
        (i) => i.status == DeliveryStatus.pending,
        index + 1,
      );
      if (next == -1) {
        next = items.indexWhere((i) => i.status == DeliveryStatus.pending);
      }
      if (next == -1) next = items.length;
    }
    state = session.copyWith(items: items, index: next);
  }
}

final broadcastProvider =
    NotifierProvider<BroadcastController, BroadcastSession?>(
      BroadcastController.new,
    );
