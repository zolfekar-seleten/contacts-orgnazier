import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps one row of a lazily built list so consecutive rows render as a single
/// rounded card with hairline dividers.
class GroupedListItem extends StatelessWidget {
  const GroupedListItem({
    super.key,
    required this.index,
    required this.count,
    required this.child,
  });

  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const r = Radius.circular(AppTheme.radius);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    final radius = BorderRadius.vertical(
      top: isFirst ? r : Radius.zero,
      bottom: isLast ? r : Radius.zero,
    );
    final side = BorderSide(color: scheme.outlineVariant);
    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: _GroupedBorder(
        radius: radius,
        side: side,
        isFirst: isFirst,
        isLast: isLast,
      ),
      child: child,
    );
  }
}

class _GroupedBorder extends ShapeBorder {
  const _GroupedBorder({
    required this.radius,
    required this.side,
    required this.isFirst,
    required this.isLast,
  });

  final BorderRadius radius;
  final BorderSide side;
  final bool isFirst;
  final bool isLast;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(radius.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = side.toPaint();
    final inset = rect.deflate(side.width / 2);
    // Draw one rounded outline that extends past the edges shared with
    // neighbouring rows, clipped to this row.
    const overflow = AppTheme.radius * 2;
    final outline = Rect.fromLTRB(
      inset.left,
      isFirst ? inset.top : inset.top - overflow,
      inset.right,
      isLast ? inset.bottom : inset.bottom + overflow,
    );
    canvas
      ..save()
      ..clipRect(rect)
      ..drawRRect(
        RRect.fromRectAndRadius(
          outline,
          const Radius.circular(AppTheme.radius),
        ),
        paint,
      );
    if (!isLast) {
      final y = rect.bottom - side.width / 2;
      canvas.drawLine(
        Offset(rect.left + 16, y),
        Offset(rect.right - 16, y),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// Small uppercase section header.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.action});

  final String title;
  final String? trailing;

  /// Optional control shown after [trailing], e.g. a search button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: action == null
          ? const EdgeInsets.fromLTRB(4, 24, 4, 10)
          : const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) Text(trailing!, style: style),
          // Shrinks instead of overflowing on narrow screens / large text.
          if (action != null)
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: action),
            ),
        ],
      ),
    );
  }
}
