import 'package:ailurus/app/router.dart';
import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
import 'package:ailurus/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AilurusApp extends ConsumerWidget {
  const AilurusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = ref
        .watch(syncSettingsProvider)
        .settings
        .languageCode;
    return MaterialApp.router(
      title: 'Ailurus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
