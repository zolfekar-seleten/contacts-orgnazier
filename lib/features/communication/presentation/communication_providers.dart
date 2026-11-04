import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_url_launcher.dart';
import '../domain/communication_service.dart';

final urlLauncherProvider = Provider<UrlLauncherGateway>(
  (ref) => const PlatformUrlLauncher(),
);

final communicationServiceProvider = Provider(
  (ref) => CommunicationService(
    ref.watch(urlLauncherProvider),
    iosStyleSms: defaultTargetPlatform == TargetPlatform.iOS,
  ),
);
