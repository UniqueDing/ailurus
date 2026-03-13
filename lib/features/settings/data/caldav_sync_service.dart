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

    int uploaded = 0;
    int deleted = 0;
    final List<String> errors = <String>[];
    final List<String> synced = <String>[];
    final Set<String> currentIds = localEvents.map((event) => event.id).toSet();

    for (final EventRecord event in localEvents) {
      final String filename = _filenameForEvent(event.id);
      final Uri resourceUri = collectionUri.resolve(filename);
      final String payload = _buildIcsPayload(event);

      try {
        final HttpClientRequest request = await client.putUrl(resourceUri);
        _setAuth(request, settings);
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'text/calendar; charset=utf-8',
        );
        request.add(utf8.encode(payload));
        final HttpClientResponse response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          uploaded += 1;
          synced.add(event.id);
        } else {
          errors.add('PUT ${event.id} failed: HTTP ${response.statusCode}');
        }
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
        _setAuth(request, settings);
        final HttpClientResponse response = await request.close();
        if (response.statusCode == 404 ||
            (response.statusCode >= 200 && response.statusCode < 300)) {
          deleted += 1;
        } else {
          errors.add('DELETE $id failed: HTTP ${response.statusCode}');
        }
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
    final Uri uri = asAbsolute != null && asAbsolute.hasScheme
        ? asAbsolute
        : server.resolve(path);

    if (!uri.path.endsWith('/')) {
      return uri.replace(path: '${uri.path}/');
    }
    return uri;
  }

  void _setAuth(HttpClientRequest request, SyncSettings settings) {
    final String raw = '${settings.username}:${settings.password}';
    final String encoded = base64Encode(utf8.encode(raw));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $encoded');
  }

  String _filenameForEvent(String eventId) {
    return 'ailurus-$eventId.ics';
  }

  String _buildIcsPayload(EventRecord event) {
    final String dtStamp = _formatUtcDateTime(DateTime.now().toUtc());
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
      final List<DateTime> occurrences = _nextLunarOccurrences(event, 2);
      if (occurrences.isEmpty) {
        body.write(
          _buildVevent(
            uid: uidBase,
            summary: '${_summary(event)} (invalid lunar)',
            description: 'Invalid lunar configuration in source app.',
            categories: event.type.name,
            dtStamp: dtStamp,
            dtStartDate: _formatDate(DateTime.now()),
            xMeta: <String, String>{
              'X-AILURUS-EVENT-TYPE': event.type.name,
              'X-AILURUS-SOURCE-CALENDAR': 'chinese-lunar',
              'X-AILURUS-INVALID': 'true',
            },
          ),
        );
      } else {
        for (int i = 0; i < occurrences.length; i++) {
          final DateTime date = occurrences[i];
          body.write(
            _buildVevent(
              uid: '$uidBase-$i',
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

  List<DateTime> _nextLunarOccurrences(EventRecord event, int count) {
    final List<DateTime> output = <DateTime>[];
    final DateTime start = DateTime.now();
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
