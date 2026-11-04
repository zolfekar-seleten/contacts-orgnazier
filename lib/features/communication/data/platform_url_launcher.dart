import 'package:url_launcher/url_launcher.dart';

import '../domain/communication_service.dart';

class PlatformUrlLauncher implements UrlLauncherGateway {
  const PlatformUrlLauncher();

  @override
  Future<bool> canLaunch(Uri uri) => canLaunchUrl(uri);

  // On iOS this maps to universal-links-only, so wa.me opens WhatsApp when
  // installed and returns false otherwise; on Android it skips browsers.
  @override
  Future<bool> launchInApp(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);

  @override
  Future<bool> launchInBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
