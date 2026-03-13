import 'package:ailurus/features/events/data/event_repository.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/events/domain/occurrence_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final EventRepository repository = EventRepository();
  ref.onDispose(repository.close);
  return repository;
});

final eventsProvider = StreamProvider<List<EventRecord>>((ref) {
  return ref.watch(eventRepositoryProvider).watchEvents();
});

final eventByIdProvider = FutureProvider.autoDispose
    .family<EventRecord?, String>((ref, id) {
      return ref.watch(eventRepositoryProvider).getById(id);
    });

final sortedOccurrencesProvider = Provider<AsyncValue<List<EventOccurrence>>>((
  ref,
) {
  final AsyncValue<List<EventRecord>> events = ref.watch(eventsProvider);
  return events.whenData((items) {
    final DateTime now = DateTime.now();
    final OccurrenceCalculator calculator = const OccurrenceCalculator();
    final List<EventOccurrence> mapped = <EventOccurrence>[];
    for (final EventRecord item in items) {
      try {
        mapped.add(calculator.describe(item, now));
      } on InvalidLunarDateException {
        continue;
      }
    }

    mapped.sort((left, right) {
      final int byDate = left.nextDate.compareTo(right.nextDate);
      if (byDate != 0) {
        return byDate;
      }
      final int byType = left.record.type.index.compareTo(
        right.record.type.index,
      );
      if (byType != 0) {
        return byType;
      }
      return left.record.displayTitle.compareTo(right.record.displayTitle);
    });
    return mapped;
  });
});
