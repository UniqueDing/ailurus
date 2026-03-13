import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EventRepository {
  EventRepository();

  static const int _schemaVersion = 1;

  final StreamController<List<EventRecord>> _controller =
      StreamController<List<EventRecord>>.broadcast();
  final Map<String, EventRecord> _items = <String, EventRecord>{};
  Future<void>? _initFuture;
  String? _storagePath;

  Stream<List<EventRecord>> watchEvents() {
    return Stream<List<EventRecord>>.multi((multi) {
      _ensureInitialized()
          .then((_) {
            multi.add(_sortedValues());
          })
          .catchError((_) {
            multi.add(_sortedValues());
          });

      final StreamSubscription<List<EventRecord>> subscription = _controller
          .stream
          .listen(multi.add, onError: multi.addError);
      multi.onCancel = () => subscription.cancel();
    });
  }

  Future<EventRecord?> getById(String id) async {
    await _ensureInitialized();
    return _items[id];
  }

  Future<void> save(EventRecord record) async {
    await _ensureInitialized();
    _items[record.id] = record;
    await _persist();
    _controller.add(_sortedValues());
  }

  Future<void> delete(String id) async {
    await _ensureInitialized();
    _items.remove(id);
    await _persist();
    _controller.add(_sortedValues());
  }

  Future<List<EventRecord>> all() async {
    await _ensureInitialized();
    return _sortedValues();
  }

  void close() {
    _controller.close();
  }

  List<EventRecord> _sortedValues() {
    final List<EventRecord> values = _items.values.toList();
    values.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return values;
  }

  Future<void> _ensureInitialized() {
    return _initFuture ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final Directory directory = await getApplicationSupportDirectory();
      _storagePath = p.join(directory.path, 'events.json');
      final File file = File(_storagePath!);
      if (!await file.exists()) {
        return;
      }

      final String content = await file.readAsString();
      if (content.trim().isEmpty) {
        return;
      }

      final Object? decoded = jsonDecode(content);
      if (decoded is Map<String, Object?>) {
        final Object? data = decoded['data'];
        if (data is List<Object?>) {
          for (final Object? item in data) {
            final EventRecord? record = EventRecord.fromJson(item);
            if (record != null) {
              _items[record.id] = record;
            }
          }
        }
      } else if (decoded is List<Object?>) {
        for (final Object? item in decoded) {
          final EventRecord? record = EventRecord.fromJson(item);
          if (record != null) {
            _items[record.id] = record;
          }
        }
      }
    } catch (_) {
      _storagePath = null;
    }
  }

  Future<void> _persist() async {
    final String? storagePath = _storagePath;
    if (storagePath == null) {
      return;
    }

    final File file = File(storagePath);
    final List<Map<String, Object?>> items = _items.values
        .map((EventRecord item) => item.toJson())
        .toList();
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'data': items,
    };
    final File temp = File('$storagePath.tmp');
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await temp.rename(file.path);
  }
}
