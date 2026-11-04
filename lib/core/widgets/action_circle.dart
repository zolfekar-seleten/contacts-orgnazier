import 'package:flutter/material.dart';

/// Round, softly tinted icon button used for quick call / WhatsApp actions.
class ActionCircle extends StatelessWidget {
  const ActionCircle({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
  });

  final Widget icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: dark ? 0.18 : 0.11),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: size * 0.5),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large circular action with a caption beneath, like the iOS contact card.
class LabeledAction extends StatelessWidget {
  const LabeledAction({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: background.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 26),
                    child: icon,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
