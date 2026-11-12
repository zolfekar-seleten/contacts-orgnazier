import 'package:flutter/material.dart';

import '../../features/contacts/domain/app_contact.dart';

/// Profile photo, or initials on a gradient picked from the contact id.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.contact,
    this.size = 44,
    this.ring = false,
  });

  final AppContact contact;
  final double size;

  /// Draws a surface-coloured ring, for avatars on top of a banner.
  final bool ring;

  static const _gradients = [
    [Color(0xFF5B8CFF), Color(0xFF3D5AF1)],
    [Color(0xFF34D3A6), Color(0xFF0E9F87)],
    [Color(0xFFA78BFA), Color(0xFF7C4DEB)],
    [Color(0xFFFFA26B), Color(0xFFF0663C)],
    [Color(0xFFFF7EB3), Color(0xFFE0457B)],
    [Color(0xFF4FC3F7), Color(0xFF1E88C7)],
    [Color(0xFFFFC857), Color(0xFFEE9B1A)],
  ];

  @override
  Widget build(BuildContext context) {
    final thumbnail = contact.thumbnail;
    final Widget child;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      child = ClipOval(
        child: Image.memory(
          thumbnail,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: pixels,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _initials(),
        ),
      );
    } else {
      child = _initials();
    }
    if (!ring) return child;
    return Container(
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _initials() =>
      InitialsAvatar(seed: contact.id, initials: contact.initials, size: size);
}

/// Gradient circle with initials; the colour is stable per [seed].
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.seed,
    required this.initials,
    this.size = 44,
  });

  final String seed;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    const gradients = ContactAvatar._gradients;
    final colors = gradients[seed.hashCode.abs() % gradients.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
