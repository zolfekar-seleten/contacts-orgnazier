import 'package:flutter/material.dart';

import '../contacts/presentation/home_screen.dart';
import '../crm/data/crm_database.dart';
import '../crm/presentation/party_list_screen.dart';

/// Bottom tab bar: Contacts, Leads and Clients. Each tab is built the first
/// time it is opened and then kept alive, so switching keeps scroll
/// positions and the database only opens when needed.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _tabs = [
    (Icons.contacts_outlined, Icons.contacts_rounded, 'Contacts'),
    (Icons.trending_up_rounded, Icons.trending_up_rounded, 'Leads'),
    (Icons.handshake_outlined, Icons.handshake_rounded, 'Clients'),
  ];

  Widget _page(int i) => switch (i) {
    0 => const HomeScreen(),
    1 => const PartyListScreen(kind: PartyKind.lead),
    _ => const PartyListScreen(kind: PartyKind.client),
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
