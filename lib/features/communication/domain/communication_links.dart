import '../../contacts/domain/phone_classifier.dart';

/// Builds `tel:` and WhatsApp URIs. Pure functions, no platform access.
abstract final class CommunicationLinks {
  /// A dialable string: E.164 when known, otherwise the cleaned raw number.
  /// Returns null when the input has fewer than 3 digits.
  static String? dialableNumber(String raw, {String? e164}) {
    final candidate = normalizePhoneInput(e164 ?? raw);
    final digits = candidate.replaceAll('+', '');
    if (digits.length < 3) return null;
    return candidate;
  }

  static Uri? telUri(String raw, {String? e164}) {
    final number = dialableNumber(raw, e164: e164);
    return number == null ? null : Uri(scheme: 'tel', path: number);
  }

  /// Digits-only international number as required by wa.me, or null if
  /// [e164] is not a plausible E.164 number.
  static String? whatsAppNumber(String? e164) {
    if (e164 == null) return null;
    final cleaned = normalizePhoneInput(e164);
    if (!cleaned.startsWith('+')) return null;
    final digits = cleaned.substring(1);
    if (digits.length < 7 || digits.length > 15 || digits.startsWith('0')) {
      return null;
    }
    return digits;
  }

  /// `https://wa.me/<number>?text=<message>`; the message is URL-encoded and
  /// omitted when blank.
  static Uri? whatsAppUri(String? e164, {String message = ''}) {
    final number = whatsAppNumber(e164);
    if (number == null) return null;
    final text = message.trim();
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$number',
      // Percent-encode (space -> %20) rather than form-encode (space -> +).
      query: text.isEmpty ? null : 'text=${Uri.encodeComponent(text)}',
    );
  }

  /// `sms:` URI with a prefilled, percent-encoded body.
  ///
  /// iOS expects `sms:<number>&body=…`; Android expects `sms:<number>?body=…`.
  static Uri? smsUri(
    String raw, {
    String? e164,
    String message = '',
    bool iosStyle = false,
  }) {
    final number = dialableNumber(raw, e164: e164);
    if (number == null) return null;
    final text = message.trim();
    if (text.isEmpty) return Uri(scheme: 'sms', path: number);
    final separator = iosStyle ? '&' : '?';
    return Uri.parse(
      'sms:$number${separator}body=${Uri.encodeComponent(text)}',
    );
  }
}
