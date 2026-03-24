import 'dart:convert';
import 'dart:io';

import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
import 'package:lunar/lunar.dart';

class CaldavSyncResult {
  const CaldavSyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.deleted,
    required this.errors,
    required this.syncedEventIds,
    required this.downloadedEvents,
    required this.updatedEvents,
  });

  final int uploaded;
  final int downloaded;
  final int deleted;
  final List<String> errors;
  final List<String> syncedEventIds;
  final List<EventRecord> downloadedEvents;
  final List<EventRecord> updatedEvents;

  String get summary {
    if (errors.isEmpty) {
      return 'Sync complete: $uploaded uploaded, $downloaded downloaded, $deleted deleted.';
    }
    return 'Sync completed with issues: $uploaded uploaded, $downloaded downloaded, $deleted deleted, ${errors.length} errors.';
  }
}

class _RemotePullResult {
  const _RemotePullResult({
    required this.events,
    required this.remoteIds,
    required this.inaccessibleRemoteIds,
    required this.collectionDiscoveryFailed,
    required this.errors,
  });

  final List<EventRecord> events;
  final Set<String> remoteIds;
  final Set<String> inaccessibleRemoteIds;
  final bool collectionDiscoveryFailed;
  final List<String> errors;
}

class CaldavSyncService {
  String buildPreviewPayload(EventRecord event, {DateTime? now}) {
    return _buildIcsPayload(event, now: now ?? DateTime.now());
  }

  Future<CaldavSyncResult> sync({
    required SyncSettings settings,
    required List<EventRecord> localEvents,
  }) async {
    final SyncSettings normalizedSettings = _normalizeSettings(settings);

    if (!_isConfigValid(normalizedSettings)) {
      return const CaldavSyncResult(
        uploaded: 0,
        downloaded: 0,
        deleted: 0,
        errors: <String>['CalDAV config is incomplete.'],
        syncedEventIds: <String>[],
        downloadedEvents: <EventRecord>[],
        updatedEvents: <EventRecord>[],
      );
    }

    final HttpClient client = HttpClient();
    final Uri? collectionUri = _collectionUri(normalizedSettings);
    if (collectionUri == null) {
      client.close(force: true);
      return const CaldavSyncResult(
        uploaded: 0,
        downloaded: 0,
        deleted: 0,
        errors: <String>['Invalid CalDAV URL or calendar path.'],
        syncedEventIds: <String>[],
        downloadedEvents: <EventRecord>[],
        updatedEvents: <EventRecord>[],
      );
    }
    if (normalizedSettings.allowInsecureTls) {
      final String expectedHost = collectionUri.host;
      final int expectedPort = _effectivePort(collectionUri);
      client.badCertificateCallback =
          (X509Certificate certificate, String host, int port) {
            return (certificate.pem.isNotEmpty || certificate.pem.isEmpty) &&
                host == expectedHost &&
                port == expectedPort;
          };
    }
    _configureAuthentication(client, normalizedSettings);
    final String? authError = await _primeAuthentication(
      client,
      collectionUri,
      normalizedSettings,
    );
    if (authError != null) {
      client.close(force: true);
      return CaldavSyncResult(
        uploaded: 0,
        downloaded: 0,
        deleted: 0,
        errors: <String>[authError],
        syncedEventIds: const <String>[],
        downloadedEvents: const <EventRecord>[],
        updatedEvents: const <EventRecord>[],
      );
    }

    final _RemotePullResult remotePull = await _pullRemoteEvents(
      client,
      collectionUri,
      normalizedSettings,
    );

    if (remotePull.collectionDiscoveryFailed) {
      client.close(force: true);
      return CaldavSyncResult(
        uploaded: 0,
        downloaded: 0,
        deleted: 0,
        errors: remotePull.errors,
        syncedEventIds: normalizedSettings.syncedEventIds,
        downloadedEvents: const <EventRecord>[],
        updatedEvents: const <EventRecord>[],
      );
    }

    final Map<String, EventRecord> remoteById = <String, EventRecord>{
      for (final EventRecord event in remotePull.events) event.id: event,
    };
    final List<EventRecord> downloadedEvents = <EventRecord>[];
    final List<EventRecord> updatedEvents = <EventRecord>[];
    final List<EventRecord> uploadCandidates = <EventRecord>[];

    final Map<String, EventRecord> syncedLocalMap = <String, EventRecord>{
      for (final EventRecord event in localEvents) event.id: event,
    };

    for (final EventRecord localEvent in localEvents) {
      final EventRecord? remoteEvent = remoteById.remove(localEvent.id);
      if (remoteEvent == null) {
        if (remotePull.inaccessibleRemoteIds.contains(localEvent.id)) {
          continue;
        }
        uploadCandidates.add(localEvent);
        continue;
      }

      if (localEvent.updatedAt.isAfter(remoteEvent.updatedAt)) {
        uploadCandidates.add(localEvent);
        continue;
      }

      if (remoteEvent.updatedAt.isAfter(localEvent.updatedAt)) {
        updatedEvents.add(remoteEvent);
        syncedLocalMap[remoteEvent.id] = remoteEvent;
      }
    }

    for (final EventRecord remainingRemote in remoteById.values) {
      downloadedEvents.add(remainingRemote);
      syncedLocalMap[remainingRemote.id] = remainingRemote;
    }

    int uploaded = 0;
    final int downloaded = downloadedEvents.length + updatedEvents.length;
    int deleted = 0;
    final List<String> errors = <String>[...remotePull.errors];
    final Set<String> synced = <String>{...remotePull.remoteIds};
    final Set<String> currentIds = syncedLocalMap.values
        .map((event) => event.id)
        .toSet();

    for (final EventRecord event in uploadCandidates) {
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
          errors.add(_authFailedMessage('PUT', event.id, normalizedSettings));
        } else {
          final String detail = await _readResponseSnippet(response);
          errors.add(
            'PUT ${event.id} failed: HTTP ${response.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
          );
        }
      } on HandshakeException catch (error) {
        errors.add(
          _tlsHandshakeErrorMessage('PUT', event.id, normalizedSettings, error),
        );
      } catch (error) {
        errors.add('PUT ${event.id} failed: $error');
      }
    }

    final Iterable<String> obsolete = normalizedSettings.syncedEventIds.where(
      (id) => !currentIds.contains(id) && !remotePull.remoteIds.contains(id),
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
          errors.add(_authFailedMessage('DELETE', id, normalizedSettings));
        } else {
          final String detail = await _readResponseSnippet(response);
          errors.add(
            'DELETE $id failed: HTTP ${response.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
          );
        }
      } on HandshakeException catch (error) {
        errors.add(
          _tlsHandshakeErrorMessage('DELETE', id, normalizedSettings, error),
        );
      } catch (error) {
        errors.add('DELETE $id failed: $error');
      }
    }

    client.close(force: true);
    return CaldavSyncResult(
      uploaded: uploaded,
      downloaded: downloaded,
      deleted: deleted,
      errors: errors,
      syncedEventIds: synced.toList(growable: false),
      downloadedEvents: downloadedEvents,
      updatedEvents: updatedEvents,
    );
  }

  Future<_RemotePullResult> _pullRemoteEvents(
    HttpClient client,
    Uri collectionUri,
    SyncSettings settings,
  ) async {
    final List<String> errors = <String>[];
    final List<EventRecord> events = <EventRecord>[];
    final Set<String> ids = <String>{};
    final Set<String> inaccessibleIds = <String>{};
    bool collectionDiscoveryFailed = false;

    try {
      final HttpClientRequest request = await client.openUrl(
        'PROPFIND',
        collectionUri,
      );
      request.headers
        ..set('Depth', '1')
        ..set(HttpHeaders.contentTypeHeader, 'application/xml; charset=utf-8');
      request.write(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>',
      );

      final HttpClientResponse response = await request.close();
      if (response.statusCode == HttpStatus.unauthorized) {
        errors.add(_authFailedMessage('PROPFIND', 'collection', settings));
        return _RemotePullResult(
          events: events,
          remoteIds: ids,
          inaccessibleRemoteIds: inaccessibleIds,
          collectionDiscoveryFailed: false,
          errors: errors,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String detail = await _readResponseSnippet(response);
        errors.add(
          'PROPFIND collection failed: HTTP ${response.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
        );
        return _RemotePullResult(
          events: events,
          remoteIds: ids,
          inaccessibleRemoteIds: inaccessibleIds,
          collectionDiscoveryFailed: true,
          errors: errors,
        );
      }

      final String xml = await response.transform(utf8.decoder).join();
      final Set<String> hrefs = _extractXmlTagValues(xml, 'href').toSet();
      for (final String rawHref in hrefs) {
        final String href = _xmlUnescape(rawHref.trim());
        if (href.isEmpty) {
          continue;
        }

        final Uri resourceUri = collectionUri.resolve(href);
        if (resourceUri.path.endsWith('/')) {
          continue;
        }

        final String filename = resourceUri.pathSegments.isEmpty
            ? ''
            : Uri.decodeComponent(resourceUri.pathSegments.last);
        final String? eventId = _idFromFilename(filename);
        if (eventId == null) {
          continue;
        }
        ids.add(eventId);

        try {
          final HttpClientRequest getRequest = await client.getUrl(resourceUri);
          final HttpClientResponse getResponse = await getRequest.close();
          if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) {
            final String ics = await getResponse.transform(utf8.decoder).join();
            final EventRecord? parsed = _parseAilurusIcs(
              eventId: eventId,
              ics: ics,
            );
            if (parsed != null) {
              events.add(parsed);
            } else {
              inaccessibleIds.add(eventId);
              errors.add('GET $eventId failed: unsupported ICS payload.');
            }
          } else if (getResponse.statusCode == HttpStatus.unauthorized) {
            inaccessibleIds.add(eventId);
            errors.add(_authFailedMessage('GET', eventId, settings));
          } else {
            inaccessibleIds.add(eventId);
            final String detail = await _readResponseSnippet(getResponse);
            errors.add(
              'GET $eventId failed: HTTP ${getResponse.statusCode}${detail.isEmpty ? '' : ' - $detail'}',
            );
          }
        } on HandshakeException catch (error) {
          inaccessibleIds.add(eventId);
          errors.add(
            _tlsHandshakeErrorMessage('GET', eventId, settings, error),
          );
        } catch (error) {
          inaccessibleIds.add(eventId);
          errors.add('GET $eventId failed: $error');
        }
      }
    } on HandshakeException catch (error) {
      collectionDiscoveryFailed = true;
      errors.add(
        _tlsHandshakeErrorMessage('PROPFIND', 'collection', settings, error),
      );
    } catch (error) {
      collectionDiscoveryFailed = true;
      errors.add('PROPFIND collection failed: $error');
    }

    return _RemotePullResult(
      events: events,
      remoteIds: ids,
      inaccessibleRemoteIds: inaccessibleIds,
      collectionDiscoveryFailed: collectionDiscoveryFailed,
      errors: errors,
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

  SyncSettings _normalizeSettings(SyncSettings settings) {
    return settings.copyWith(
      serverUrl: settings.serverUrl.trim(),
      username: settings.username.trim(),
      password: settings.password.trimRight(),
      calendarPath: settings.calendarPath.trim(),
    );
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
            'X-AILURUS-SOURCE-YEAR': (event.sourceYear ?? start.year)
                .toString(),
            'X-AILURUS-SOURCE-MONTH': event.sourceMonth.toString(),
            'X-AILURUS-SOURCE-DAY': event.sourceDay.toString(),
            'X-AILURUS-IS-LEAP-MONTH': event.isLeapMonth.toString(),
            'X-AILURUS-IS-PINNED': event.isPinned.toString(),
            'X-AILURUS-IS-FAVORITE': event.isFavorite.toString(),
            'X-AILURUS-TITLE': event.title,
            'X-AILURUS-PERSON-NAME': event.personName ?? '',
            'X-AILURUS-TIMEZONE': event.timezone,
            'X-AILURUS-CREATED-AT': event.createdAt.toIso8601String(),
            'X-AILURUS-UPDATED-AT': event.updatedAt.toIso8601String(),
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
              'X-AILURUS-IS-PINNED': event.isPinned.toString(),
              'X-AILURUS-IS-FAVORITE': event.isFavorite.toString(),
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
              'X-AILURUS-IS-PINNED': event.isPinned.toString(),
              'X-AILURUS-IS-FAVORITE': event.isFavorite.toString(),
              'X-AILURUS-TITLE': event.title,
              'X-AILURUS-PERSON-NAME': event.personName ?? '',
              'X-AILURUS-TIMEZONE': event.timezone,
              'X-AILURUS-CREATED-AT': event.createdAt.toIso8601String(),
              'X-AILURUS-UPDATED-AT': event.updatedAt.toIso8601String(),
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

  EventRecord? _parseAilurusIcs({
    required String eventId,
    required String ics,
  }) {
    final Map<String, String> values = _parseIcsValues(ics);
    if (values.isEmpty) {
      return null;
    }

    final String summary = values['SUMMARY']?.trim() ?? '';
    final String description = values['DESCRIPTION']?.trim() ?? '';
    final String dtStartRaw = values['DTSTART']?.trim() ?? '';
    final DateTime? dtStart = _parseIcsDate(dtStartRaw);
    if (dtStart == null) {
      return null;
    }

    final EventType eventType = _eventTypeFromIcs(values);
    final CalendarType calendarType =
        values['X-AILURUS-SOURCE-CALENDAR'] == 'chinese-lunar'
        ? CalendarType.chineseLunar
        : CalendarType.gregorian;

    final int sourceMonth =
        int.tryParse(values['X-AILURUS-SOURCE-MONTH'] ?? '') ?? dtStart.month;
    final int sourceDay =
        int.tryParse(values['X-AILURUS-SOURCE-DAY'] ?? '') ?? dtStart.day;
    final int? sourceYear = calendarType == CalendarType.gregorian
        ? (int.tryParse(values['X-AILURUS-SOURCE-YEAR'] ?? '') ?? dtStart.year)
        : null;
    final bool isLeapMonth =
        (values['X-AILURUS-IS-LEAP-MONTH'] ?? '').toLowerCase() == 'true';
    final bool isPinned =
        (values['X-AILURUS-IS-PINNED'] ?? '').toLowerCase() == 'true';
    final bool isFavorite =
        (values['X-AILURUS-IS-FAVORITE'] ?? '').toLowerCase() == 'true';

    final String titleFromMeta = values['X-AILURUS-TITLE']?.trim() ?? '';
    final String personNameFromMeta =
        values['X-AILURUS-PERSON-NAME']?.trim() ?? '';
    final String fallbackTitle = _stripSummarySuffix(summary, eventType);
    final String title = titleFromMeta.isNotEmpty
        ? titleFromMeta
        : (fallbackTitle.isNotEmpty ? fallbackTitle : summary);
    if (title.trim().isEmpty) {
      return null;
    }

    final DateTime createdAt =
        DateTime.tryParse(values['X-AILURUS-CREATED-AT'] ?? '') ??
        _parseIcsDateTime(values['DTSTAMP']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final DateTime updatedAt =
        DateTime.tryParse(values['X-AILURUS-UPDATED-AT'] ?? '') ??
        _parseIcsDateTime(values['LAST-MODIFIED']) ??
        _parseIcsDateTime(values['DTSTAMP']) ??
        createdAt;

    return EventRecord(
      id: eventId,
      type: eventType,
      title: title,
      personName: personNameFromMeta.isNotEmpty
          ? personNameFromMeta
          : (fallbackTitle.isNotEmpty ? fallbackTitle : title),
      personGender: null,
      personRelationship: null,
      calendarType: calendarType,
      sourceYear: sourceYear,
      sourceMonth: sourceMonth,
      sourceDay: sourceDay,
      isLeapMonth: isLeapMonth,
      timezone: values['X-AILURUS-TIMEZONE']?.trim().isNotEmpty == true
          ? values['X-AILURUS-TIMEZONE']!.trim()
          : 'local',
      note: description.isEmpty ? null : description,
      isPinned: isPinned,
      isFavorite: isFavorite,
      reminderPolicy: const ReminderPolicy(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, String> _parseIcsValues(String rawIcs) {
    final List<String> unfolded = _unfoldIcsLines(rawIcs);
    final Map<String, String> out = <String, String>{};
    for (final String line in unfolded) {
      final int delimiter = line.indexOf(':');
      if (delimiter <= 0) {
        continue;
      }
      final String rawKey = line.substring(0, delimiter).trim();
      final String value = _unescapeText(line.substring(delimiter + 1));
      final String key = rawKey.split(';').first.toUpperCase();
      out[key] = value;
    }
    return out;
  }

  List<String> _unfoldIcsLines(String rawIcs) {
    final List<String> rows = rawIcs.replaceAll('\r\n', '\n').split('\n');
    final List<String> unfolded = <String>[];
    for (final String row in rows) {
      if (row.startsWith(' ') || row.startsWith('\t')) {
        if (unfolded.isNotEmpty) {
          unfolded[unfolded.length - 1] = '${unfolded.last}${row.substring(1)}';
        }
      } else {
        unfolded.add(row);
      }
    }
    return unfolded;
  }

  DateTime? _parseIcsDate(String value) {
    final String compact = value.replaceAll('-', '').trim();
    if (compact.length < 8) {
      return null;
    }
    final int? year = int.tryParse(compact.substring(0, 4));
    final int? month = int.tryParse(compact.substring(4, 6));
    final int? day = int.tryParse(compact.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  DateTime? _parseIcsDateTime(String? value) {
    if (value == null) {
      return null;
    }
    final String compact = value.trim();
    if (compact.isEmpty) {
      return null;
    }

    final String normalized = compact.endsWith('Z')
        ? compact.substring(0, compact.length - 1)
        : compact;
    final RegExp utcPattern = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$',
    );
    final Match? utcMatch = utcPattern.firstMatch(normalized);
    if (utcMatch != null) {
      final int? year = int.tryParse(utcMatch.group(1)!);
      final int? month = int.tryParse(utcMatch.group(2)!);
      final int? day = int.tryParse(utcMatch.group(3)!);
      final int? hour = int.tryParse(utcMatch.group(4)!);
      final int? minute = int.tryParse(utcMatch.group(5)!);
      final int? second = int.tryParse(utcMatch.group(6)!);
      if (year == null ||
          month == null ||
          day == null ||
          hour == null ||
          minute == null ||
          second == null) {
        return null;
      }
      if (compact.endsWith('Z')) {
        return DateTime.utc(year, month, day, hour, minute, second).toLocal();
      }
      return DateTime(year, month, day, hour, minute, second);
    }

    return DateTime.tryParse(compact);
  }

  EventType _eventTypeFromIcs(Map<String, String> values) {
    final String? fromMeta = values['X-AILURUS-EVENT-TYPE'];
    if (fromMeta != null) {
      for (final EventType type in EventType.values) {
        if (type.name == fromMeta) {
          return type;
        }
      }
    }

    final String categories = (values['CATEGORIES'] ?? '').toLowerCase();
    if (categories.contains('anniversary')) {
      return EventType.anniversary;
    }
    return EventType.birthday;
  }

  String _stripSummarySuffix(String summary, EventType type) {
    final String suffix = ' - ${type.label}';
    if (summary.endsWith(suffix)) {
      return summary.substring(0, summary.length - suffix.length).trim();
    }
    return summary.trim();
  }

  List<String> _extractXmlTagValues(String xml, String tagName) {
    final RegExp exp = RegExp(
      '<(?:\\w+:)?$tagName[^>]*>([\\s\\S]*?)</(?:\\w+:)?$tagName>',
      caseSensitive: false,
    );
    return exp
        .allMatches(xml)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _xmlUnescape(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  String? _idFromFilename(String filename) {
    if (!filename.startsWith('ailurus-') || !filename.endsWith('.ics')) {
      return null;
    }
    final String id = filename.substring(
      'ailurus-'.length,
      filename.length - 4,
    );
    if (id.trim().isEmpty) {
      return null;
    }
    return id;
  }

  String _unescapeText(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\');
  }
}
