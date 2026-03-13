import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:lunar/lunar.dart';

class InvalidLunarDateException implements Exception {
  const InvalidLunarDateException(this.eventId);

  final String eventId;

  @override
  String toString() {
    return 'InvalidLunarDateException(eventId: $eventId)';
  }
}

class OccurrenceCalculator {
  const OccurrenceCalculator();

  EventOccurrence describe(EventRecord record, DateTime anchor) {
    final DateTime start = DateTime(anchor.year, anchor.month, anchor.day);
    final DateTime nextDate = switch (record.calendarType) {
      CalendarType.gregorian => _nextGregorian(record, start),
      CalendarType.chineseLunar => _nextLunar(record, start),
    };
    final int daysUntil = nextDate.difference(start).inDays;
    final int? occurrenceNumber = record.sourceYear == null
        ? null
        : nextDate.year - record.sourceYear!;

    return EventOccurrence(
      record: record,
      nextDate: nextDate,
      daysUntil: daysUntil,
      occurrenceNumber: occurrenceNumber,
      isToday: daysUntil == 0,
    );
  }

  DateTime _nextGregorian(EventRecord record, DateTime anchor) {
    for (int year = anchor.year; year <= anchor.year + 120; year++) {
      final DateTime? candidate = _resolveGregorianForYear(record, year);
      if (candidate != null && !candidate.isBefore(anchor)) {
        return candidate;
      }
    }
    return _safeDate(anchor.year, record.sourceMonth, record.sourceDay);
  }

  DateTime _nextLunar(EventRecord record, DateTime anchor) {
    for (int year = anchor.year; year <= anchor.year + 120; year++) {
      final DateTime? candidate = _resolveLunarForYear(record, year);
      if (candidate != null && !candidate.isBefore(anchor)) {
        return candidate;
      }
    }

    throw InvalidLunarDateException(record.id);
  }

  DateTime _safeDate(int year, int month, int day) {
    final int clampedDay = day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, clampedDay);
  }

  int _daysInMonth(int year, int month) {
    if (month == DateTime.december) {
      return 31;
    }
    final DateTime firstDayNextMonth = DateTime(year, month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1)).day;
  }

  DateTime? _resolveGregorianForYear(EventRecord record, int year) {
    if (record.sourceMonth == 2 &&
        record.sourceDay == 29 &&
        !_isLeapYear(year)) {
      return switch (record.feb29Policy) {
        Feb29Policy.feb28 => DateTime(year, 2, 28),
        Feb29Policy.march1 => DateTime(year, 3, 1),
        Feb29Policy.strictLeapOnly => null,
      };
    }
    return _safeDate(year, record.sourceMonth, record.sourceDay);
  }

  DateTime? _resolveLunarForYear(EventRecord record, int year) {
    final List<LunarMonth> months = LunarYear.fromYear(year).getMonthsInYear();
    if (months.isEmpty) {
      return null;
    }

    final int? token = _resolveMonthToken(record, year, months);
    if (token == null) {
      return null;
    }

    final DateTime? exact = _tryLunarDate(year, token, record.sourceDay);
    if (exact != null) {
      return exact;
    }

    switch (record.lunarMissingDayPolicy) {
      case LunarMissingDayPolicy.skipYear:
        return null;
      case LunarMissingDayPolicy.previousDay:
        final LunarMonth? month = LunarMonth.fromYm(year, token);
        if (month == null) {
          return null;
        }
        return _tryLunarDate(year, token, month.getDayCount());
      case LunarMissingDayPolicy.nextMonthFirst:
        final int? nextToken = _nextMonthToken(months, token);
        if (nextToken == null) {
          return null;
        }
        return _tryLunarDate(year, nextToken, 1);
    }
  }

  int? _resolveMonthToken(
    EventRecord record,
    int year,
    List<LunarMonth> months,
  ) {
    final int origin = record.isLeapMonth
        ? -record.sourceMonth
        : record.sourceMonth;
    if (_tokenExists(months, origin)) {
      return origin;
    }
    if (!record.isLeapMonth) {
      return null;
    }

    switch (record.lunarLeapMonthPolicy) {
      case LunarLeapMonthPolicy.strict:
        return null;
      case LunarLeapMonthPolicy.regularMonth:
        return _tokenExists(months, record.sourceMonth)
            ? record.sourceMonth
            : null;
      case LunarLeapMonthPolicy.nextMonth:
        if (!_tokenExists(months, record.sourceMonth)) {
          return null;
        }
        return _nextMonthToken(months, record.sourceMonth);
    }
  }

  bool _tokenExists(List<LunarMonth> months, int token) {
    return months.any((month) => month.getMonth() == token);
  }

  int? _nextMonthToken(List<LunarMonth> months, int token) {
    for (int i = 0; i < months.length; i++) {
      if (months[i].getMonth() == token) {
        if (i + 1 >= months.length) {
          return null;
        }
        return months[i + 1].getMonth();
      }
    }
    return null;
  }

  DateTime? _tryLunarDate(int year, int monthToken, int day) {
    try {
      final Lunar lunar = Lunar.fromYmd(year, monthToken, day);
      final Solar solar = lunar.getSolar();
      return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
    } catch (_) {
      return null;
    }
  }

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }
}
