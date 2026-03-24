import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
import 'package:ailurus/l10n/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _serverController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _calendarController;
  late bool _allowInsecureTls;
  late AppThemeMode _themeMode;
  late AppColorPalette _colorPalette;
  bool _hasLocalEdits = false;
  bool _isSyncingFromState = false;

  @override
  void initState() {
    super.initState();
    final SyncSettings settings = ref.read(syncSettingsProvider).settings;
    _serverController = TextEditingController(text: settings.serverUrl);
    _userController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _calendarController = TextEditingController(text: settings.calendarPath);
    _allowInsecureTls = settings.allowInsecureTls;
    _themeMode = settings.themeMode;
    _colorPalette = settings.colorPalette;
    _serverController.addListener(_markLocalEdit);
    _userController.addListener(_markLocalEdit);
    _passwordController.addListener(_markLocalEdit);
    _calendarController.addListener(_markLocalEdit);
  }

  void _markLocalEdit() {
    if (_isSyncingFromState) {
      return;
    }
    _hasLocalEdits = true;
  }

  void _syncFormFromState(SyncSettings settings) {
    if (_hasLocalEdits) {
      return;
    }

    _isSyncingFromState = true;
    if (_serverController.text != settings.serverUrl) {
      _serverController.text = settings.serverUrl;
    }
    if (_userController.text != settings.username) {
      _userController.text = settings.username;
    }
    if (_passwordController.text != settings.password) {
      _passwordController.text = settings.password;
    }
    if (_calendarController.text != settings.calendarPath) {
      _calendarController.text = settings.calendarPath;
    }
    _allowInsecureTls = settings.allowInsecureTls;
    _themeMode = settings.themeMode;
    _colorPalette = settings.colorPalette;
    _isSyncingFromState = false;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SyncUiState uiState = ref.watch(syncSettingsProvider);
    final SyncSettings settings = uiState.settings;
    _syncFormFromState(settings);

    return Scaffold(
      appBar: AppBar(title: Text(AppTexts.settings(context))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              AppTexts.settingsOverview(context),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            Text(
              AppTexts.appearance(context),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppTexts.themeMode(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppThemeMode>(
                      segments: <ButtonSegment<AppThemeMode>>[
                        ButtonSegment<AppThemeMode>(
                          value: AppThemeMode.system,
                          label: Text(AppTexts.themeSystem(context)),
                        ),
                        ButtonSegment<AppThemeMode>(
                          value: AppThemeMode.light,
                          label: Text(AppTexts.themeLight(context)),
                        ),
                        ButtonSegment<AppThemeMode>(
                          value: AppThemeMode.dark,
                          label: Text(AppTexts.themeDark(context)),
                        ),
                      ],
                      selected: <AppThemeMode>{_themeMode},
                      onSelectionChanged: (Set<AppThemeMode> values) async {
                        final AppThemeMode next = values.first;
                        setState(() {
                          _themeMode = next;
                        });
                        await ref
                            .read(syncSettingsProvider.notifier)
                            .setThemeMode(next);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppTexts.colorPalette(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<AppColorPalette>(
                        initialValue: _colorPalette,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        borderRadius: BorderRadius.circular(18),
                        items: AppColorPalette.values
                            .map(
                              (palette) => DropdownMenuItem<AppColorPalette>(
                                value: palette,
                                child: Text(
                                  AppTexts.paletteName(context, palette),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (AppColorPalette? value) async {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _colorPalette = value;
                          });
                          await ref
                              .read(syncSettingsProvider.notifier)
                              .setColorPalette(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(AppTexts.general(context), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppTexts.language(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        initialValue: settings.languageCode,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        borderRadius: BorderRadius.circular(18),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'zh',
                            child: Text('中文'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'en',
                            child: Text('English'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'ja',
                            child: Text('日本語'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'ko',
                            child: Text('한국어'),
                          ),
                        ],
                        onChanged: (String? value) async {
                          if (value == null) {
                            return;
                          }
                          await ref
                              .read(syncSettingsProvider.notifier)
                              .setLanguageCode(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(AppTexts.caldav(context), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        labelText: AppTexts.serverUrl(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: AppTexts.username(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: AppTexts.password(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _calendarController,
                      decoration: InputDecoration(
                        labelText: AppTexts.calendarPath(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      value: _allowInsecureTls,
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppTexts.allowInsecureTls(context)),
                      subtitle: Text(AppTexts.allowInsecureTlsHint(context)),
                      onChanged: (bool value) {
                        setState(() {
                          _allowInsecureTls = value;
                          _hasLocalEdits = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(AppTexts.saveSyncSettings(context)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: uiState.isSyncing
                                ? null
                                : () async {
                                    await ref
                                        .read(syncSettingsProvider.notifier)
                                        .syncNow();
                                  },
                            icon: uiState.isSyncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(
                              uiState.isSyncing
                                  ? AppTexts.syncing(context)
                                  : AppTexts.syncNow(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppTexts.currentConnection(context)),
                      subtitle: Text(
                        settings.serverUrl.isEmpty
                            ? AppTexts.noConfig(context)
                            : '${settings.serverUrl}\n${settings.username}\n${settings.calendarPath}\n${AppTexts.syncedIds(context)}: ${settings.syncedEventIds.length}',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppTexts.syncStatus(context)),
                      subtitle: Text(
                        [
                          if (settings.lastSyncAtIso != null)
                            '${AppTexts.lastSync(context)}: ${settings.lastSyncAtIso}',
                          if (settings.lastSyncError != null &&
                              settings.lastSyncError!.isNotEmpty)
                            '${AppTexts.lastError(context)}: ${settings.lastSyncError}',
                          if (uiState.statusMessage != null)
                            uiState.statusMessage!,
                          if (settings.lastSyncAtIso == null &&
                              uiState.statusMessage == null)
                            AppTexts.noSyncYet(context),
                        ].join('\n'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(AppTexts.about(context), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(AppTexts.aboutApp(context)),
                    subtitle: const Text('Ailurus 1.0.0+1'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Ailurus 1.0.0+1'),
                          content: Text(AppTexts.aboutAppDescription(context)),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                MaterialLocalizations.of(context).okButtonLabel,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    await ref
        .read(syncSettingsProvider.notifier)
        .save(
          serverUrl: _serverController.text.trim(),
          username: _userController.text.trim(),
          password: _passwordController.text.trimRight(),
          calendarPath: _calendarController.text.trim(),
          allowInsecureTls: _allowInsecureTls,
          themeMode: _themeMode,
          colorPalette: _colorPalette,
        );
    _hasLocalEdits = false;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppTexts.saveOk(context))));
  }
}
