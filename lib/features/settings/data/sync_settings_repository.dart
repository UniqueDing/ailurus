import 'dart:convert';
import 'dart:io';

import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SyncSettingsRepository {
  static const int _schemaVersion = 1;

  Future<SyncSettings> load() async {
    try {
      final File file = await _settingsFile();
      if (!await file.exists()) {
        return const SyncSettings();
      }

      final String content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const SyncSettings();
      }

      final Object? decoded = jsonDecode(content);
      if (decoded is Map<String, Object?>) {
        final Object? data = decoded['data'];
        if (data != null) {
          return SyncSettings.fromJson(data);
        }
      }
      return SyncSettings.fromJson(decoded);
    } catch (_) {
      return const SyncSettings();
    }
  }

  Future<void> save(SyncSettings settings) async {
    final File file = await _settingsFile();
    final File temp = File('${file.path}.tmp');
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'data': settings.toJson(),
    };
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await temp.rename(file.path);
  }

  Future<File> _settingsFile() async {
    final Directory directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'sync_settings.json'));
  }
}
