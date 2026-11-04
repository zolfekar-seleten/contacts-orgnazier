import 'package:flutter/material.dart';

import '../../features/countries/domain/country.dart';

/// Emoji flag in a rounded tile; a globe for the Unknown bucket.
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, required this.country, this.size = 44});

  final Country? country;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: country == null
          ? Icon(
              Icons.public_rounded,
              size: size * 0.52,
              color: scheme.onSurfaceVariant,
            )
          : Text(
              country!.flag,
              style: TextStyle(fontSize: size * 0.56, height: 1.1),
              semanticsLabel: '${country!.name} flag',
            ),
    );
  }
}
