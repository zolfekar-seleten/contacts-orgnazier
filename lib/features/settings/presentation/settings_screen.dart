import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../countries/domain/country.dart';
import '../domain/app_settings.dart';
import 'region_picker_screen.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final deviceRegion = Country.fromIso(ref.watch(deviceRegionProvider));
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );

    final regionOptions = <(RegionPreference, String, String)>[
      (
        RegionPreference.device,
        'Use device region',
        deviceRegion == null
            ? 'Device region unknown, so local numbers stay uncategorised'
            : '${deviceRegion.flag} ${deviceRegion.name}',
      ),
      (
        settings.region is ManualRegion
            ? settings.region
            : const ManualRegion(''),
        'Choose a region',
        switch (settings.region) {
          ManualRegion(:final isoCode) =>
            Country.fromIso(isoCode)?.let((c) => '${c.flag} ${c.name}') ??
                isoCode,
          _ => 'Pick the country your local numbers belong to',
        },
      ),
      (
        RegionPreference.none,
        'Don’t assume a region',
        'Only numbers with a country code are categorised',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: contentPadding(context).copyWith(bottom: 32),
        children: [
          const SectionHeader('Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SectionHeader('Local numbers'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Numbers saved without a country code (like 050 123 4567) '
              'could belong to many countries. Choose how to interpret them.',
              style: muted,
            ),
          ),
          for (var i = 0; i < regionOptions.length; i++)
            GroupedListItem(
              index: i,
              count: regionOptions.length,
              child: _RegionOption(
                title: regionOptions[i].$2,
                subtitle: regionOptions[i].$3,
                selected: switch ((regionOptions[i].$1, settings.region)) {
                  (DeviceRegion(), DeviceRegion()) => true,
                  (NoRegion(), NoRegion()) => true,
                  (ManualRegion(), ManualRegion()) => true,
                  _ => false,
                },
                onTap: () async {
                  final option = regionOptions[i].$1;
                  if (option is ManualRegion) {
                    final picked = await Navigator.of(context).push<Country>(
                      MaterialPageRoute(
                        builder: (_) => const RegionPickerScreen(),
                      ),
                    );
                    if (picked != null) {
                      controller.setRegion(ManualRegion(picked.isoCode));
                    }
                  } else {
                    controller.setRegion(option);
                  }
                },
              ),
            ),
          const SectionHeader('Contacts'),
          GroupedListItem(
            index: 0,
            count: 2,
            child: ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Reload contacts'),
              onTap: () {
                ref.read(contactsControllerProvider.notifier).refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reloading contacts…')),
                );
              },
            ),
          ),
          GroupedListItem(
            index: 1,
            count: 2,
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Contacts permission'),
              subtitle: const Text('Manage access in system Settings'),
              onTap: () =>
                  ref.read(contactsControllerProvider.notifier).openSettings(),
            ),
          ),
          const SectionHeader('Privacy'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Contacts are read and categorised entirely on this '
                      'device. Nothing is uploaded, and your address book is '
                      'never modified. Calls and WhatsApp messages only start '
                      'when you tap, and messages are sent from WhatsApp '
                      'itself.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  const _RegionOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      selected: selected,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? scheme.secondary : scheme.outline,
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
