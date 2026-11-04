import '../../contacts/domain/app_contact.dart';

/// Placeholders that are replaced per recipient.
enum NameToken {
  firstName('first_name', 'First name'),
  lastName('last_name', 'Last name'),
  fullName('full_name', 'Full name');

  const NameToken(this.key, this.label);

  final String key;
  final String label;

  /// Text inserted into the message, e.g. `{first_name}`.
  String get placeholder => '{$key}';

  String valueFor(AppContact contact) => switch (this) {
    NameToken.firstName => contact.firstName,
    NameToken.lastName => contact.lastName,
    NameToken.fullName => contact.displayName,
  };
}

/// Renders a message template for a specific contact.
abstract final class MessageTemplate {
  // Tolerates `{ First_Name }` style variations.
  static final _token = RegExp(
    r'\{\s*(first_name|last_name|full_name)\s*\}',
    caseSensitive: false,
  );

  static bool hasTokens(String template) => _token.hasMatch(template);

  static String render(String template, AppContact contact) {
    final filled = template.replaceAllMapped(_token, (m) {
      final key = m.group(1)!.toLowerCase();
      final token = NameToken.values.firstWhere((t) => t.key == key);
      return token.valueFor(contact);
    });
    // An empty name (e.g. no last name) must not leave odd spacing behind.
    return filled
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAllMapped(RegExp(r'[ \t]+([,.!?;:])'), (m) => m.group(1)!)
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }
}
