import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_view.dart';
import '../domain/contacts_repository.dart';
import 'contacts_providers.dart';

/// Explains why contacts access is needed before the OS prompt, and guides
/// the user to Settings when access was permanently denied.
class PermissionView extends ConsumerWidget {
  const PermissionView({super.key, required this.status});

  final ContactsPermission status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(contactsControllerProvider.notifier);
    final theme = Theme.of(context);
    final privacy = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Processed on this device only. Never uploaded or changed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    return switch (status) {
      ContactsPermission.notDetermined => StateView(
        icon: Icons.contacts_rounded,
        title: 'See your contacts by country',
        message:
            'Contacts Organizer reads the phone numbers in your address book to '
            'group people by country, so you can find, call or message them '
            'quickly.',
        primaryLabel: 'Allow contacts access',
        onPrimary: controller.requestAccess,
        footer: privacy,
      ),
      ContactsPermission.denied => StateView(
        icon: Icons.contacts_rounded,
        title: 'Contacts access needed',
        message:
            'Without access to your contacts there is nothing to organise. '
            'You can allow access whenever you’re ready.',
        primaryLabel: 'Try again',
        onPrimary: controller.requestAccess,
        footer: privacy,
      ),
      ContactsPermission.permanentlyDenied => StateView(
        icon: Icons.settings_outlined,
        title: 'Turn on contacts access',
        message:
            'Contacts access is turned off for Contacts Organizer. Open Settings '
            'and allow access to Contacts, then come back.',
        primaryLabel: 'Open Settings',
        onPrimary: controller.openSettings,
        footer: privacy,
      ),
      ContactsPermission.restricted => const StateView(
        icon: Icons.block_rounded,
        title: 'Contacts access restricted',
        message:
            'Access to contacts is restricted on this device, for example by '
            'parental controls or a device policy.',
      ),
      // Not reachable: granted states never show this view.
      ContactsPermission.granted ||
      ContactsPermission.limited => const SizedBox.shrink(),
    };
  }
}
