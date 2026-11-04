import 'communication_links.dart';

/// Outcome of trying to start a phone call. Opening the dialer is not the
/// same as a completed call.
enum CallResult { dialerOpened, invalidNumber, unsupported, failed }

/// Outcome of trying to open a WhatsApp chat. Opening WhatsApp never means a
/// message was sent; the user reviews and sends it inside WhatsApp.
enum WhatsAppResult {
  appOpened,
  webOpened,
  invalidNumber,
  notInstalled,
  failed,
}

/// Outcome of opening the Messages app. Never means the SMS was sent.
enum SmsResult { composerOpened, invalidNumber, unsupported, failed }

/// Thin seam over the platform URL launcher so it can be mocked in tests.
abstract interface class UrlLauncherGateway {
  Future<bool> canLaunch(Uri uri);

  /// Opens [uri] in a native app only (never the browser).
  Future<bool> launchInApp(Uri uri);

  /// Opens [uri] in the external browser.
  Future<bool> launchInBrowser(Uri uri);
}

/// Starts calls and WhatsApp conversations. Never acts without an explicit
/// user action from the caller, and never sends messages itself.
class CommunicationService {
  const CommunicationService(this._launcher, {this.iosStyleSms = false});

  final UrlLauncherGateway _launcher;

  /// Whether to build iOS-style `sms:` URIs (`&body=`).
  final bool iosStyleSms;

  /// Opens the Messages composer for [raw]/[e164] with [message] prefilled.
  Future<SmsResult> openSms(
    String raw, {
    String? e164,
    String message = '',
  }) async {
    final uri = CommunicationLinks.smsUri(
      raw,
      e164: e164,
      message: message,
      iosStyle: iosStyleSms,
    );
    if (uri == null) return SmsResult.invalidNumber;
    try {
      if (!await _launcher.canLaunch(uri)) return SmsResult.unsupported;
      return await _launcher.launchInApp(uri)
          ? SmsResult.composerOpened
          : SmsResult.failed;
    } on Exception {
      return SmsResult.failed;
    }
  }

  Future<CallResult> call(String raw, {String? e164}) async {
    final uri = CommunicationLinks.telUri(raw, e164: e164);
    if (uri == null) return CallResult.invalidNumber;
    try {
      if (!await _launcher.canLaunch(uri)) return CallResult.unsupported;
      return await _launcher.launchInApp(uri)
          ? CallResult.dialerOpened
          : CallResult.failed;
    } on Exception {
      return CallResult.failed;
    }
  }

  /// Opens the WhatsApp chat for [e164] with [message] prefilled. When
  /// WhatsApp is not installed returns [WhatsAppResult.notInstalled] so the UI
  /// can offer [openWhatsAppWeb].
  Future<WhatsAppResult> openWhatsApp(
    String? e164, {
    String message = '',
  }) async {
    final uri = CommunicationLinks.whatsAppUri(e164, message: message);
    if (uri == null) return WhatsAppResult.invalidNumber;
    try {
      return await _launcher.launchInApp(uri)
          ? WhatsAppResult.appOpened
          : WhatsAppResult.notInstalled;
    } on Exception {
      return WhatsAppResult.notInstalled;
    }
  }

  Future<WhatsAppResult> openWhatsAppWeb(
    String? e164, {
    String message = '',
  }) async {
    final uri = CommunicationLinks.whatsAppUri(e164, message: message);
    if (uri == null) return WhatsAppResult.invalidNumber;
    try {
      return await _launcher.launchInBrowser(uri)
          ? WhatsAppResult.webOpened
          : WhatsAppResult.failed;
    } on Exception {
      return WhatsAppResult.failed;
    }
  }
}
