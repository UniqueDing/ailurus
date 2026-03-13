import 'package:ailurus/core/calendar/calendar_type.dart';

enum EventType { birthday, anniversary }

enum PersonGender { unspecified, male, female, other }

enum PersonRelationship { family, partner, friend, colleague, classmate, other }

enum LunarLeapMonthPolicy { regularMonth, strict, nextMonth }

enum LunarMissingDayPolicy { previousDay, skipYear, nextMonthFirst }

enum Feb29Policy { feb28, march1, strictLeapOnly }

extension EventTypeX on EventType {
  String get label {
    return switch (this) {
      EventType.birthday => 'Birthday',
      EventType.anniversary => 'Anniversary',
    };
  }
}

class ReminderPolicy {
  const ReminderPolicy({
    this.offsetsInDays = const <int>[0],
    this.localTime = '09:00',
  });

  final List<int> offsetsInDays;
  final String localTime;

  Map<String, Object> toJson() {
    final List<int> sorted = offsetsInDays.toList()..sort();
    return <String, Object>{'offsetsInDays': sorted, 'localTime': localTime};
  }

  static ReminderPolicy fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const ReminderPolicy();
    }

    if (value['offsetsInDays'] is List<Object?>) {
      final List<int> offsets =
          (value['offsetsInDays']! as List<Object?>)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
      return ReminderPolicy(
        offsetsInDays: offsets.isEmpty ? const <int>[0] : offsets,
        localTime: value['localTime'] is String
            ? value['localTime']! as String
            : '09:00',
      );
    }

    final bool sameDayEnabled = value['sameDayEnabled'] is bool
        ? value['sameDayEnabled']! as bool
        : true;
    final bool oneDayBeforeEnabled = value['oneDayBeforeEnabled'] is bool
        ? value['oneDayBeforeEnabled']! as bool
        : false;
    final List<int> fallback = <int>[
      if (sameDayEnabled) 0,
      if (oneDayBeforeEnabled) 1,
    ];

    return ReminderPolicy(
      offsetsInDays: fallback.isEmpty ? const <int>[0] : fallback,
      localTime: value['sameDayLocalTime'] is String
          ? value['sameDayLocalTime']! as String
          : '09:00',
    );
  }
}

class EventRecord {
  const EventRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.personName,
    this.personGender,
    this.personRelationship,
    required this.calendarType,
    required this.sourceYear,
    required this.sourceMonth,
    required this.sourceDay,
    required this.isLeapMonth,
    required this.timezone,
    required this.note,
    required this.reminderPolicy,
    this.lunarLeapMonthPolicy = LunarLeapMonthPolicy.regularMonth,
    this.lunarMissingDayPolicy = LunarMissingDayPolicy.previousDay,
    this.feb29Policy = Feb29Policy.feb28,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final EventType type;
  final String title;
  final String? personName;
  final PersonGender? personGender;
  final PersonRelationship? personRelationship;
  final CalendarType calendarType;
  final int? sourceYear;
  final int sourceMonth;
  final int sourceDay;
  final bool isLeapMonth;
  final String timezone;
  final String? note;
  final ReminderPolicy reminderPolicy;
  final LunarLeapMonthPolicy lunarLeapMonthPolicy;
  final LunarMissingDayPolicy lunarMissingDayPolicy;
  final Feb29Policy feb29Policy;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle =>
      personName?.trim().isNotEmpty == true ? personName!.trim() : title;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'title': title,
      'personName': personName,
      'personGender': personGender?.name,
      'personRelationship': personRelationship?.name,
      'calendarType': calendarType.name,
      'sourceYear': sourceYear,
      'sourceMonth': sourceMonth,
      'sourceDay': sourceDay,
      'isLeapMonth': isLeapMonth,
      'timezone': timezone,
      'note': note,
      'reminderPolicy': reminderPolicy.toJson(),
      'lunarLeapMonthPolicy': lunarLeapMonthPolicy.name,
      'lunarMissingDayPolicy': lunarMissingDayPolicy.name,
      'feb29Policy': feb29Policy.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static EventRecord? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final String? id = _asString(value['id']);
    final String? typeName = _asString(value['type']);
    final String? title = _asString(value['title']);
    final String? calendarTypeName = _asString(value['calendarType']);
    final int? sourceMonth = _asInt(value['sourceMonth']);
    final int? sourceDay = _asInt(value['sourceDay']);
    final String? timezone = _asString(value['timezone']);
    final String? createdAtValue = _asString(value['createdAt']);
    final String? updatedAtValue = _asString(value['updatedAt']);
    if (id == null ||
        typeName == null ||
        title == null ||
        calendarTypeName == null ||
        sourceMonth == null ||
        sourceDay == null ||
        timezone == null ||
        createdAtValue == null ||
        updatedAtValue == null) {
      return null;
    }

    final EventType? type = _parseEventType(typeName);
    final CalendarType? calendarType = _parseCalendarType(calendarTypeName);
    final LunarLeapMonthPolicy lunarLeapMonthPolicy =
        _parseLunarLeapMonthPolicy(_asString(value['lunarLeapMonthPolicy'])) ??
        LunarLeapMonthPolicy.regularMonth;
    final LunarMissingDayPolicy lunarMissingDayPolicy =
        _parseLunarMissingDayPolicy(
          _asString(value['lunarMissingDayPolicy']),
        ) ??
        LunarMissingDayPolicy.previousDay;
    final Feb29Policy feb29Policy =
        _parseFeb29Policy(_asString(value['feb29Policy'])) ?? Feb29Policy.feb28;
    if (type == null || calendarType == null) {
      return null;
    }

    final DateTime? createdAt = DateTime.tryParse(createdAtValue);
    final DateTime? updatedAt = DateTime.tryParse(updatedAtValue);
    if (createdAt == null || updatedAt == null) {
      return null;
    }

    return EventRecord(
      id: id,
      type: type,
      title: title,
      personName: _asString(value['personName']),
      personGender: _parsePersonGender(_asString(value['personGender'])),
      personRelationship: _parsePersonRelationship(
        _asString(value['personRelationship']),
      ),
      calendarType: calendarType,
      sourceYear: _asInt(value['sourceYear']),
      sourceMonth: sourceMonth,
      sourceDay: sourceDay,
      isLeapMonth: value['isLeapMonth'] is bool
          ? value['isLeapMonth']! as bool
          : false,
      timezone: timezone,
      note: _asString(value['note']),
      reminderPolicy: ReminderPolicy.fromJson(value['reminderPolicy']),
      lunarLeapMonthPolicy: lunarLeapMonthPolicy,
      lunarMissingDayPolicy: lunarMissingDayPolicy,
      feb29Policy: feb29Policy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static int? _asInt(Object? value) {
    return value is int ? value : null;
  }

  static EventType? _parseEventType(String name) {
    for (final EventType value in EventType.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static CalendarType? _parseCalendarType(String name) {
    for (final CalendarType value in CalendarType.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static PersonGender? _parsePersonGender(String? name) {
    if (name == null) {
      return null;
    }
    for (final PersonGender value in PersonGender.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static PersonRelationship? _parsePersonRelationship(String? name) {
    if (name == null) {
      return null;
    }
    for (final PersonRelationship value in PersonRelationship.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static LunarLeapMonthPolicy? _parseLunarLeapMonthPolicy(String? name) {
    for (final LunarLeapMonthPolicy value in LunarLeapMonthPolicy.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static LunarMissingDayPolicy? _parseLunarMissingDayPolicy(String? name) {
    for (final LunarMissingDayPolicy value in LunarMissingDayPolicy.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static Feb29Policy? _parseFeb29Policy(String? name) {
    for (final Feb29Policy value in Feb29Policy.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

class EventOccurrence {
  const EventOccurrence({
    required this.record,
    required this.nextDate,
    required this.daysUntil,
    required this.occurrenceNumber,
    required this.isToday,
  });

  final EventRecord record;
  final DateTime nextDate;
  final int daysUntil;
  final int? occurrenceNumber;
  final bool isToday;
}
