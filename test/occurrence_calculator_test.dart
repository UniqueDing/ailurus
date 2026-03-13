import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/events/domain/occurrence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OccurrenceCalculator calculator = OccurrenceCalculator();

  test('gregorian occurrences stay on the closest upcoming date', () {
    final EventRecord record = EventRecord(
      id: '1',
      type: EventType.birthday,
      title: 'Lin',
      personName: 'Lin',
      calendarType: CalendarType.gregorian,
      sourceYear: 1996,
      sourceMonth: 6,
      sourceDay: 18,
      isLeapMonth: false,
      timezone: 'Asia/Shanghai',
      note: null,
      reminderPolicy: const ReminderPolicy(),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final EventOccurrence occurrence = calculator.describe(
      record,
      DateTime(2026, 6, 10),
    );

    expect(occurrence.nextDate, DateTime(2026, 6, 18));
    expect(occurrence.daysUntil, 8);
    expect(occurrence.occurrenceNumber, 30);
  });

  test('lunar dates resolve to a real future solar date', () {
    final EventRecord record = EventRecord(
      id: '2',
      type: EventType.anniversary,
      title: 'Moon date',
      personName: null,
      calendarType: CalendarType.chineseLunar,
      sourceYear: 2020,
      sourceMonth: 8,
      sourceDay: 15,
      isLeapMonth: false,
      timezone: 'Asia/Shanghai',
      note: null,
      reminderPolicy: const ReminderPolicy(),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final EventOccurrence occurrence = calculator.describe(
      record,
      DateTime(2026, 1, 1),
    );

    expect(occurrence.nextDate.isAfter(DateTime(2025, 12, 31)), isTrue);
    expect(occurrence.daysUntil >= 0, isTrue);
  });
}
