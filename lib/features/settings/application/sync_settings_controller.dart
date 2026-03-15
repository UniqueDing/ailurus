import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/settings/data/caldav_sync_service.dart';
import 'package:ailurus/features/settings/data/sync_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { system, light, dark }

extension AppThemeModeCodec on AppThemeMode {
  String get key => name;

  static AppThemeMode fromKey(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

class SyncSettings {
  const SyncSettings({
    this.serverUrl = '',
    this.username = '',
    this.password = '',
    this.calendarPath = '',
    this.allowInsecureTls = false,
    this.languageCode = 'zh',
    this.themeMode = AppThemeMode.system,
    this.syncedEventIds = const <String>[],
    this.lastSyncAtIso,
    this.lastSyncError,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String calendarPath;
  final bool allowInsecureTls;
  final String languageCode;
  final AppThemeMode themeMode;
  final List<String> syncedEventIds;
  final String? lastSyncAtIso;
  final String? lastSyncError;

  SyncSettings copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? calendarPath,
    bool? allowInsecureTls,
    String? languageCode,
    AppThemeMode? themeMode,
    List<String>? syncedEventIds,
    String? lastSyncAtIso,
    String? lastSyncError,
    bool clearLastSyncAtIso = false,
    bool clearLastSyncError = false,
  }) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      calendarPath: calendarPath ?? this.calendarPath,
      allowInsecureTls: allowInsecureTls ?? this.allowInsecureTls,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      syncedEventIds: syncedEventIds ?? this.syncedEventIds,
      lastSyncAtIso: clearLastSyncAtIso
          ? null
          : (lastSyncAtIso ?? this.lastSyncAtIso),
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'calendarPath': calendarPath,
      'allowInsecureTls': allowInsecureTls,
      'languageCode': languageCode,
      'themeMode': themeMode.key,
      'syncedEventIds': syncedEventIds,
      'lastSyncAtIso': lastSyncAtIso,
      'lastSyncError': lastSyncError,
    };
  }

  static SyncSettings fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const SyncSettings();
    }

    return SyncSettings(
      serverUrl: value['serverUrl'] is String
          ? value['serverUrl']! as String
          : '',
      username: value['username'] is String ? value['username']! as String : '',
      password: value['password'] is String ? value['password']! as String : '',
      calendarPath: value['calendarPath'] is String
          ? value['calendarPath']! as String
          : '',
      allowInsecureTls: value['allowInsecureTls'] is bool
          ? value['allowInsecureTls']! as bool
          : false,
      languageCode: value['languageCode'] is String
          ? value['languageCode']! as String
          : 'zh',
      themeMode: AppThemeModeCodec.fromKey(
        value['themeMode'] is String ? value['themeMode']! as String : null,
      ),
      syncedEventIds: value['syncedEventIds'] is List<Object?>
          ? (value['syncedEventIds']! as List<Object?>)
                .whereType<String>()
                .toList(growable: false)
          : const <String>[],
      lastSyncAtIso: value['lastSyncAtIso'] is String
          ? value['lastSyncAtIso']! as String
          : null,
      lastSyncError: value['lastSyncError'] is String
          ? value['lastSyncError']! as String
          : null,
    );
  }
}

class SyncUiState {
  const SyncUiState({
    required this.settings,
    required this.isSyncing,
    required this.statusMessage,
  });

  final SyncSettings settings;
  final bool isSyncing;
  final String? statusMessage;

  SyncUiState copyWith({
    SyncSettings? settings,
    bool? isSyncing,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return SyncUiState(
      settings: settings ?? this.settings,
      isSyncing: isSyncing ?? this.isSyncing,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
    );
  }
}

class SyncSettingsNotifier extends Notifier<SyncUiState> {
  @override
  SyncUiState build() {
    _load();
    return const SyncUiState(
      settings: SyncSettings(),
      isSyncing: false,
      statusMessage: null,
    );
  }

  Future<void> _load() async {
    final SyncSettings loaded = await ref
        .read(syncSettingsRepositoryProvider)
        .load();
    state = state.copyWith(settings: loaded);
  }

  Future<void> save({
    required String serverUrl,
    required String username,
    required String password,
    required String calendarPath,
    required bool allowInsecureTls,
    String? languageCode,
    AppThemeMode? themeMode,
  }) async {
    final SyncSettings updated = state.settings.copyWith(
      serverUrl: serverUrl,
      username: username,
      password: password,
      calendarPath: calendarPath,
      allowInsecureTls: allowInsecureTls,
      languageCode: languageCode,
      themeMode: themeMode,
      clearLastSyncError: true,
    );
    state = state.copyWith(
      settings: updated,
      statusMessage: _isZh(updated) ? '同步设置已保存。' : 'Sync settings saved.',
    );
    await ref.read(syncSettingsRepositoryProvider).save(updated);
  }

  Future<void> syncNow() async {
    final SyncSettings settings = state.settings;
    state = state.copyWith(
      isSyncing: true,
      statusMessage: _isZh(settings)
          ? '正在同步到 CalDAV...'
          : 'Syncing to CalDAV...',
    );

    final CaldavSyncResult result = await ref
        .read(caldavSyncServiceProvider)
        .sync(
          settings: settings,
          localEvents: await ref.read(eventRepositoryProvider).all(),
        );

    final SyncSettings nextSettings = settings.copyWith(
      syncedEventIds: result.syncedEventIds,
      lastSyncAtIso: DateTime.now().toIso8601String(),
      lastSyncError: result.errors.isEmpty ? null : result.errors.join(' | '),
    );
    await ref.read(syncSettingsRepositoryProvider).save(nextSettings);

    state = state.copyWith(
      settings: nextSettings,
      isSyncing: false,
      statusMessage: _syncSummary(nextSettings, result),
    );
  }

  Future<void> setLanguageCode(String code) async {
    final SyncSettings updated = state.settings.copyWith(languageCode: code);
    state = state.copyWith(settings: updated, clearStatusMessage: true);
    await ref.read(syncSettingsRepositoryProvider).save(updated);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final SyncSettings updated = state.settings.copyWith(themeMode: mode);
    state = state.copyWith(settings: updated, clearStatusMessage: true);
    await ref.read(syncSettingsRepositoryProvider).save(updated);
  }

  bool _isZh(SyncSettings settings) {
    return settings.languageCode.toLowerCase().startsWith('zh');
  }

  String _syncSummary(SyncSettings settings, CaldavSyncResult result) {
    if (_isZh(settings)) {
      if (result.errors.isEmpty) {
        return '同步完成：上传 ${result.uploaded} 条，删除 ${result.deleted} 条。';
      }
      return '同步完成：上传 ${result.uploaded} 条，删除 ${result.deleted} 条，错误 ${result.errors.length} 条。';
    }
    if (result.errors.isEmpty) {
      return 'Sync complete: ${result.uploaded} uploaded, ${result.deleted} deleted.';
    }
    return 'Sync complete: ${result.uploaded} uploaded, ${result.deleted} deleted, ${result.errors.length} errors.';
  }
}

final syncSettingsRepositoryProvider = Provider<SyncSettingsRepository>((ref) {
  return SyncSettingsRepository();
});

final caldavSyncServiceProvider = Provider<CaldavSyncService>((ref) {
  return CaldavSyncService();
});

final syncSettingsProvider =
    NotifierProvider<SyncSettingsNotifier, SyncUiState>(
      SyncSettingsNotifier.new,
    );
