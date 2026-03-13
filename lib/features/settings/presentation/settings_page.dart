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

  @override
  void initState() {
    super.initState();
    final SyncSettings settings = ref.read(syncSettingsProvider).settings;
    _serverController = TextEditingController(text: settings.serverUrl);
    _userController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _calendarController = TextEditingController(text: settings.calendarPath);
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

    return Scaffold(
      appBar: AppBar(title: Text(AppTexts.settings(context))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppTexts.caldav(context),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Text(
                          AppTexts.language(context),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: settings.languageCode,
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'zh',
                              child: Text(AppTexts.languageName(context, 'zh')),
                            ),
                            DropdownMenuItem<String>(
                              value: 'en',
                              child: Text(AppTexts.languageName(context, 'en')),
                            ),
                            DropdownMenuItem<String>(
                              value: 'ja',
                              child: Text(AppTexts.languageName(context, 'ja')),
                            ),
                            DropdownMenuItem<String>(
                              value: 'ko',
                              child: Text(AppTexts.languageName(context, 'ko')),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppTexts.syncIntro(context),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppTexts.passwordMemoryOnly(context),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        labelText: AppTexts.serverUrl(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: AppTexts.username(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: AppTexts.password(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _calendarController,
                      decoration: InputDecoration(
                        labelText: AppTexts.calendarPath(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(syncSettingsProvider.notifier)
                            .save(
                              serverUrl: _serverController.text.trim(),
                              username: _userController.text.trim(),
                              password: _passwordController.text,
                              calendarPath: _calendarController.text.trim(),
                            );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppTexts.saveOk(context))),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(AppTexts.saveSyncSettings(context)),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        uiState.isSyncing
                            ? AppTexts.syncing(context)
                            : AppTexts.syncNow(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(AppTexts.currentConnection(context)),
                subtitle: Text(
                  settings.serverUrl.isEmpty
                      ? AppTexts.noConfig(context)
                      : '${settings.serverUrl}\n${settings.username}\n${settings.calendarPath}\n${AppTexts.syncedIds(context)}: ${settings.syncedEventIds.length}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(AppTexts.syncStatus(context)),
                subtitle: Text(
                  [
                    if (settings.lastSyncAtIso != null)
                      '${AppTexts.lastSync(context)}: ${settings.lastSyncAtIso}',
                    if (settings.lastSyncError != null &&
                        settings.lastSyncError!.isNotEmpty)
                      '${AppTexts.lastError(context)}: ${settings.lastSyncError}',
                    if (uiState.statusMessage != null) uiState.statusMessage!,
                    if (settings.lastSyncAtIso == null &&
                        uiState.statusMessage == null)
                      AppTexts.noSyncYet(context),
                  ].join('\n'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
