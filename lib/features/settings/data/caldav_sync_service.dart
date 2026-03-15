import 'dart:convert';
import 'dart:io';

import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
import 'package:lunar/lunar.dart';

class CaldavSyncResult {
  const CaldavSyncResult({
    required this.uploaded,
    required this.deleted,
    required this.errors,
    required this.syncedEventIds,
  });

  final int uploaded;
  final int deleted;
  final List<String> errors;
  final List<String> syncedEventIds;

  String get summary {
    if (errors.isEmpty) {
      return 'Sync complete: $uploaded uploaded, $deleted deleted.';
    }
    return 'Sync completed with issues: $uploaded uploaded, $deleted deleted, ${errors.length} errors.';
  }
}

class CaldavSyncService {
  String buildPreviewPayload(EventRecord event, {DateTime? now}) {
    return _buildIcsPayload(event, now: now ?? DateTime.now());
  }

  Future<CaldavSyncResult> sync({
    required SyncSettings settings,
    required List<EventRecord> localEvents,
  }) async {
    if (!_isConfigValid(settings)) {
      return const CaldavSyncResult(
        uploaded: 0,
        deleted: 0,
        errors: <String>['CalDAV config is incomplete.'],
        syncedEventIds: <String>[],
      );
    }

    final HttpClient client = HttpClient();
    final Uri? collectionUri = _collectionUri(settings);
    if (collectionUri == null) {
      client.close(force: true);
      return const CaldavSyncResult(
        uploaded: 0,
        deleted: 0,
        errors: <String>['Invalid CalDAV URL or calendar path.'],
        syncedEventIds: <String>[],
      );
    }
    if (settings.allowInsecureTls) {
      final String expectedHost = collectionUri.host;
      final int expectedPort = _effectivePort(collectionUri);
      client.badCertificateCallback =
          (X509Certificate certificate, String host, int port) {
            return (certificate.pem.isNotEmpty || certificate.pem.isEmpty) &&
                host == expectedHost &&
                port == expectedPort;
          };
    }
    _configureAuthentication(client, settings);
    final String? authError = await _primeAuthentication(
      client,
      collectionUri,
      settings,
    );
    if (authError != null) {
      client.close(force: true);
      return CaldavSyncResult(
        uploaded: 0,
        deleted: 0,
        errors: <String>[authError],
        syncedEventIds: const <String>[],
      );
    }

    int uploaded = 0;
    int deleted = 0;
    final List<String> errors = <String>[];
    final List<String> synced = <String>[];
    final Set<String> currentIds = localEvents.map((event) => event.id).toSet();

    for (final EventRecord event in localEvents) {
      final String filename = _filenameForEvent(event.id);
      final Uri resourceUri = collectionUri.resolve(filename);
      final String payload = _buildIcsPayload(event, now: DateTime.now());

      try {
        final HttpClientRequest request = await client.putUrl(resourceUri);
        request.headers.set(HttpHeaders.contentTypeHeader, 'text/calendar');
        request.add(utf8.encode(payload));
        final HttpClientResponse response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          uploaded += 1;
          synced.add(event.id);
        } else if (response.statusCode == HttpStatus.unauthorized) {
          errors.add(_authFailedMessage('PUT', event.id, settings));
        } else {
          final String detail = await _readResponseSnippet(response);
          errors.add(
            'PUT ${event.id} failed: HTTP ${response.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
          );
        }
      } on HandshakeException catch (error) {
        errors.add(_tlsHandshakeErrorMessage('PUT', event.id, settings, error));
      } catch (error) {
        errors.add('PUT ${event.id} failed: $error');
      }
    }

    final Iterable<String> obsolete = settings.syncedEventIds.where(
      (id) => !currentIds.contains(id),
    );
    for (final String id in obsolete) {
      final Uri resourceUri = collectionUri.resolve(_filenameForEvent(id));
      try {
        final HttpClientRequest request = await client.deleteUrl(resourceUri);
        final HttpClientResponse response = await request.close();
        if (response.statusCode == 404 ||
            (response.statusCode >= 200 && response.statusCode < 300)) {
          deleted += 1;
        } else if (response.statusCode == HttpStatus.unauthorized) {
          errors.add(_authFailedMessage('DELETE', id, settings));
        } else {
          final String detail = await _readResponseSnippet(response);
          errors.add(
            'DELETE $id failed: HTTP ${response.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
          );
        }
      } on HandshakeException catch (error) {
        errors.add(_tlsHandshakeErrorMessage('DELETE', id, settings, error));
      } catch (error) {
        errors.add('DELETE $id failed: $error');
      }
    }

    client.close(force: true);
    return CaldavSyncResult(
      uploaded: uploaded,
      deleted: deleted,
      errors: errors,
      syncedEventIds: synced,
    );
  }

  bool _isConfigValid(SyncSettings settings) {
    return settings.serverUrl.trim().isNotEmpty &&
        settings.username.trim().isNotEmpty &&
        settings.password.trim().isNotEmpty &&
        settings.calendarPath.trim().isNotEmpty;
  }

  Uri? _collectionUri(SyncSettings settings) {
    final Uri? server = Uri.tryParse(settings.serverUrl.trim());
    if (server == null || !server.hasScheme || !server.hasAuthority) {
      return null;
    }

    final String path = settings.calendarPath.trim();
    final Uri? asAbsolute = Uri.tryParse(path);
    final Uri uri;
    if (asAbsolute != null && asAbsolute.hasScheme) {
      uri = asAbsolute;
    } else if (_isCalendarNameOnly(path)) {
      uri = _resolveCalendarNameOnlyUri(server, settings.username.trim(), path);
    } else if (path.startsWith('/')) {
      uri = _resolveAbsolutePathOnServer(server, path);
    } else {
      uri = server.resolve(path);
    }

    if (!uri.path.endsWith('/')) {
      return uri.replace(path: '${uri.path}/');
    }
    return uri;
  }

  bool _isCalendarNameOnly(String path) {
    if (path.isEmpty) {
      return false;
    }
    return !path.contains('/') && !path.contains('\\');
  }

  Uri _resolveCalendarNameOnlyUri(Uri server, String username, String name) {
    if (username.isEmpty) {
      return server.resolve(name);
    }
    final String base = _davBasePath(server.path);
    final String fullPath = _joinUrlPaths(base, 'calendars/$username/$name');
    return server.replace(path: fullPath);
  }

  String _davBasePath(String serverPath) {
    if (serverPath.isEmpty || serverPath == '/') {
      return '/dav.php';
    }
    final int marker = serverPath.indexOf('/dav.php');
    if (marker >= 0) {
      return serverPath.substring(0, marker + '/dav.php'.length);
    }
    return serverPath.endsWith('/')
        ? serverPath.substring(0, serverPath.length - 1)
        : serverPath;
  }

  Uri _resolveAbsolutePathOnServer(Uri server, String path) {
    final String serverPath = server.path;
    if (serverPath.isEmpty || serverPath == '/') {
      return server.replace(path: path);
    }

    if (path == serverPath || path.startsWith('$serverPath/')) {
      return server.replace(path: path);
    }

    final String merged = _joinUrlPaths(serverPath, path);
    return server.replace(path: merged);
  }

  String _joinUrlPaths(String left, String right) {
    final String normalizedLeft = left.endsWith('/')
        ? left.substring(0, left.length - 1)
        : left;
    final String normalizedRight = right.startsWith('/')
        ? right.substring(1)
        : right;
    return '$normalizedLeft/$normalizedRight';
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return uri.scheme == 'https' ? 443 : 80;
  }

  void _configureAuthentication(HttpClient client, SyncSettings settings) {
    client.authenticate = (Uri url, String scheme, String? realm) async {
      final String lowered = scheme.toLowerCase();
      if (realm == null || realm.isEmpty) {
        return false;
      }
      if (lowered == 'digest') {
        client.addCredentials(
          url,
          realm,
          HttpClientDigestCredentials(settings.username, settings.password),
        );
        return true;
      }
      if (lowered == 'basic') {
        client.addCredentials(
          url,
          realm,
          HttpClientBasicCredentials(settings.username, settings.password),
        );
        return true;
      }
      return false;
    };
  }

  Future<String?> _primeAuthentication(
    HttpClient client,
    Uri collectionUri,
    SyncSettings settings,
  ) async {
    try {
      final HttpClientRequest request = await client.openUrl(
        'PROPFIND',
        collectionUri,
      );
      request.headers.set('Depth', '0');
      final HttpClientResponse response = await request.close();
      if (response.statusCode == HttpStatus.unauthorized) {
        return _authConfigErrorMessage(settings);
      }
      return null;
    } catch (error) {
      return _isZh(settings)
          ? '认证预检失败：$error'
          : 'Authentication bootstrap failed: $error';
    }
  }

  String _authConfigErrorMessage(SyncSettings settings) {
    if (_isZh(settings)) {
      return '认证失败：服务器拒绝凭据。请检查用户名/密码，或确认服务器是否要求 Digest 认证。';
    }
    return 'Authentication failed: server rejected credentials. Check username/password or whether the server requires Digest auth.';
  }

  String _authFailedMessage(String method, String id, SyncSettings settings) {
    if (_isZh(settings)) {
      return '$method $id 失败: 认证失败（401）。请检查用户名/密码或认证方式。';
    }
    return '$method $id failed: authentication failed (401). Check username/password or auth scheme.';
  }

  Future<String> _readResponseSnippet(HttpClientResponse response) async {
    try {
      final String body = await response.transform(utf8.decoder).join();
      final String compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (compact.isEmpty) {
        return '';
      }
      if (compact.length <= 220) {
        return compact;
      }
      return '${compact.substring(0, 220)}...';
    } catch (_) {
      return '';
    }
  }

  String _tlsHandshakeErrorMessage(
    String method,
    String id,
    SyncSettings settings,
    HandshakeException error,
  ) {
    if (_isZh(settings)) {
      if (settings.allowInsecureTls) {
        return '$method $id 失败: TLS 握手异常（已允许不安全 TLS）: $error';
      }
      return '$method $id 失败: TLS 握手异常。若服务器使用自签名证书，请在设置中启用“不安全 TLS”。详细信息: $error';
    }

    if (settings.allowInsecureTls) {
      return '$method $id failed: TLS handshake exception (insecure TLS already enabled): $error';
    }
    return '$method $id failed: TLS handshake exception. If your server uses a self-signed certificate, enable insecure TLS in Settings. Details: $error';
  }

  bool _isZh(SyncSettings settings) {
    return settings.languageCode.toLowerCase().startsWith('zh');
  }

  String _filenameForEvent(String eventId) {
    return 'ailurus-$eventId.ics';
  }

  String _buildIcsPayload(EventRecord event, {required DateTime now}) {
    final String dtStamp = _formatUtcDateTime(now.toUtc());
    final String uidBase = 'ailurus-${event.id}@ailurus.app';

    final StringBuffer body = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Ailurus//Calendar Sync//EN')
      ..writeln('CALSCALE:GREGORIAN');

    if (event.calendarType == CalendarType.gregorian) {
      final DateTime start = _gregorianStart(event);
      body.write(
        _buildVevent(
          uid: uidBase,
          summary: _summary(event),
          description: _description(event),
          categories: event.type.name,
          dtStamp: dtStamp,
          dtStartDate: _formatDate(start),
          rrule: 'FREQ=YEARLY',
          xMeta: <String, String>{
            'X-AILURUS-EVENT-TYPE': event.type.name,
            'X-AILURUS-SOURCE-CALENDAR': 'gregorian',
          },
        ),
      );
    } else {
      final List<DateTime> occurrences = _nextLunarOccurrences(event, 1, now);
      if (occurrences.isEmpty) {
        body.write(
          _buildVevent(
            uid: uidBase,
            summary: '${_summary(event)} (invalid lunar)',
            description: 'Invalid lunar configuration in source app.',
            categories: event.type.name,
            dtStamp: dtStamp,
            dtStartDate: _formatDate(now),
            xMeta: <String, String>{
              'X-AILURUS-EVENT-TYPE': event.type.name,
              'X-AILURUS-SOURCE-CALENDAR': 'chinese-lunar',
              'X-AILURUS-INVALID': 'true',
            },
          ),
        );
      } else {
        final DateTime date = occurrences.first;
        body.write(
          _buildVevent(
            uid: uidBase,
            summary: _summary(event),
            description: _description(event),
            categories: event.type.name,
            dtStamp: dtStamp,
            dtStartDate: _formatDate(date),
            xMeta: <String, String>{
              'X-AILURUS-EVENT-TYPE': event.type.name,
              'X-AILURUS-SOURCE-CALENDAR': 'chinese-lunar',
              'X-AILURUS-SOURCE-MONTH': event.sourceMonth.toString(),
              'X-AILURUS-SOURCE-DAY': event.sourceDay.toString(),
              'X-AILURUS-IS-LEAP-MONTH': event.isLeapMonth.toString(),
              'X-AILURUS-GROUP-ID': event.id,
            },
          ),
        );
      }
    }

    body.writeln('END:VCALENDAR');
    return body.toString();
  }

  String _buildVevent({
    required String uid,
    required String summary,
    required String description,
    required String categories,
    required String dtStamp,
    required String dtStartDate,
    String? rrule,
    Map<String, String> xMeta = const <String, String>{},
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${_escapeText(uid)}')
      ..writeln('DTSTAMP:$dtStamp')
      ..writeln('DTSTART;VALUE=DATE:$dtStartDate')
      ..writeln('SUMMARY:${_escapeText(summary)}')
      ..writeln('DESCRIPTION:${_escapeText(description)}')
      ..writeln('CATEGORIES:${_escapeText(categories)}');

    if (rrule != null && rrule.isNotEmpty) {
      b.writeln('RRULE:$rrule');
    }
    for (final MapEntry<String, String> entry in xMeta.entries) {
      b.writeln('${entry.key}:${_escapeText(entry.value)}');
    }
    b.writeln('END:VEVENT');
    return b.toString();
  }

  DateTime _gregorianStart(EventRecord event) {
    final int year = event.sourceYear ?? 2000;
    final int month = event.sourceMonth;
    final int day = event.sourceDay.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  List<DateTime> _nextLunarOccurrences(
    EventRecord event,
    int count,
    DateTime start,
  ) {
    final List<DateTime> output = <DateTime>[];
    for (int offset = 0; offset <= 2600 && output.length < count; offset++) {
      final DateTime candidate = start.add(Duration(days: offset));
      final Lunar lunar = Solar.fromYmd(
        candidate.year,
        candidate.month,
        candidate.day,
      ).getLunar();
      final int month = lunar.getMonth();
      final bool leap = month < 0;
      if (month.abs() == event.sourceMonth &&
          lunar.getDay() == event.sourceDay &&
          leap == event.isLeapMonth) {
        output.add(candidate);
      }
    }
    return output;
  }

  int _daysInMonth(int year, int month) {
    if (month == DateTime.december) {
      return 31;
    }
    return DateTime(year, month + 1, 1).subtract(const Duration(days: 1)).day;
  }

  String _summary(EventRecord event) {
    return '${event.displayTitle} - ${event.type.label}';
  }

  String _description(EventRecord event) {
    final String note = event.note?.trim().isNotEmpty == true
        ? event.note!.trim()
        : 'Ailurus event';
    return note;
  }

  String _formatDate(DateTime date) {
    final int year = date.year;
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _formatUtcDateTime(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    final String second = date.second.toString().padLeft(2, '0');
    return '$year$month${day}T$hour$minute${second}Z';
  }

  String _escapeText(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }
}
