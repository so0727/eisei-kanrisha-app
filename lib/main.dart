import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'utils/local_notification_service.dart';
import 'providers/app_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  await LocalNotificationService().init();
  await LocalNotificationService().requestPermissions();
  
  runApp(
    const ProviderScope(
      child: EiseiKanrishaAppWrapper(),
    ),
  );
}

class EiseiKanrishaAppWrapper extends ConsumerWidget {
  const EiseiKanrishaAppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(appSettings.textScale),
      ),
      child: const EiseiKanrishaApp(),
    );
  }
}
