import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

/// アプリ本体のウィジェット
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';

class EiseiKanrishaApp extends ConsumerWidget {
  const EiseiKanrishaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp.router(
      title: '衛生管理者(第1種) 爆速合格',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
