import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Floating pill search input. Owns its [TextEditingController] (ephemeral UI
/// state) and forwards text to [onChanged]; the debounced query lives in a
/// provider.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow(theme.brightness),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: widget.hint,
          fillColor: scheme.surfaceContainerLowest,
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search_rounded, color: scheme.secondary),
          suffixIcon: ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    color: scheme.onSurfaceVariant,
                    onPressed: _clear,
                  ),
          ),
        ),
      ),
    );
  }
}
