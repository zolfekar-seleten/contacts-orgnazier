import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/contacts/presentation/home_screen.dart';
import 'features/settings/presentation/settings_providers.dart';

class CountryContactsApp extends ConsumerWidget {
  const CountryContactsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Contacts Organizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const HomeScreen(),
    );
  }
}
