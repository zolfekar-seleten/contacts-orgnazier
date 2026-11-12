import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contacts/presentation/home_screen.dart';
import '../crm/data/crm_database.dart';
import '../crm/presentation/activities_screen.dart';
import '../crm/presentation/party_list_screen.dart';
import '../sync/presentation/cloud_providers.dart';

/// Bottom tab bar: Contacts, Leads, Clients and Activities. Each tab is
/// built the first time it is opened and then kept alive, so switching
/// keeps scroll positions and the database only opens when needed.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    // Sync and the daily iCloud backup run on launch and on resume.
    Future.microtask(() => ref.read(cloudControllerProvider.notifier).start());
  }

  static const _tabs = [
    (Icons.contacts_outlined, Icons.contacts_rounded, 'Contacts'),
    (Icons.trending_up_rounded, Icons.trending_up_rounded, 'Leads'),
    (Icons.handshake_outlined, Icons.handshake_rounded, 'Clients'),
    (Icons.event_note_outlined, Icons.event_note_rounded, 'Activities'),
  ];

  Widget _page(int i) => switch (i) {
    0 => const HomeScreen(),
    1 => const PartyListScreen(kind: PartyKind.lead),
    2 => const PartyListScreen(kind: PartyKind.client),
    _ => const ActivitiesScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: [
          for (final (icon, selected, label) in _tabs)
            NavigationDestination(
              key: ValueKey('tab-${label.toLowerCase()}'),
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
