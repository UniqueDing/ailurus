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
    final SyncSettings settings = ref.watch(syncSettingsProvider).settings;
    final String languageCode = settings.languageCode;
    final AppColorPalette palette = settings.colorPalette;
    final ThemeMode themeMode = switch (settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'Ailurus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeMode,
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
