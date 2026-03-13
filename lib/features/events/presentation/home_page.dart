import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/l10n/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EventOccurrence>> occurrences = ref.watch(
      sortedOccurrencesProvider,
    );
    final bool wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTexts.appTitle(context)),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: () => context.push('/event/new'),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/event/new'),
              child: const Icon(Icons.add),
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppTheme.cream,
              AppTheme.sand.withValues(alpha: 0.7),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 5,
                        child: _HeroPanel(dateLabel: _todayLabel(context)),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 7,
                        child: _EventsPanel(occurrences: occurrences),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _HeroPanel(dateLabel: _todayLabel(context)),
                      const SizedBox(height: 20),
                      _EventsPanel(occurrences: occurrences),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _todayLabel(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.occurrences});

  final AsyncValue<List<EventOccurrence>> occurrences;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: occurrences.when(
          data: (List<EventOccurrence> items) {
            if (items.isEmpty) {
              return _EmptyState(onAdd: () => context.push('/event/new'));
            }

            final List<EventOccurrence> today = items
                .where((item) => item.isToday)
                .toList();
            final List<EventOccurrence> upcoming = items
                .where((item) => item.daysUntil > 0 && item.daysUntil <= 30)
                .toList();
            final List<EventOccurrence> later = items
                .where((item) => item.daysUntil > 30)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTexts.isZh(context) ? '最近事项' : 'Upcoming',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                if (today.isNotEmpty)
                  _Section(title: AppTexts.today(context), items: today),
                if (upcoming.isNotEmpty)
                  _Section(
                    title: AppTexts.next30Days(context),
                    items: upcoming,
                  ),
                if (later.isNotEmpty)
                  _Section(title: AppTexts.later(context), items: later),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (Object error, StackTrace _) => Text(
            AppTexts.unableLoadDates(context, error),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.moss,
            AppTheme.moss.withValues(alpha: 0.92),
            AppTheme.copper,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              dateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppTexts.heroSlogan(context),
            style: theme.textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<EventOccurrence> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.item});

  final EventOccurrence item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push('/event/${item.record.id}'),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget icon = Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: item.record.type == EventType.birthday
                    ? AppTheme.blush.withValues(alpha: 0.78)
                    : AppTheme.sand.withValues(alpha: 0.85),
              ),
              child: Icon(
                item.record.type == EventType.birthday
                    ? Icons.cake_rounded
                    : Icons.favorite_rounded,
                color: AppTheme.ink,
              ),
            );

            final Widget main = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.record.displayTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Chip(
                        label: Text(
                          item.record.type == EventType.birthday
                              ? AppTexts.birthday(context)
                              : AppTexts.anniversary(context),
                        ),
                      ),
                      Chip(
                        label: Text(
                          item.record.calendarType == CalendarType.gregorian
                              ? AppTexts.gregorian(context)
                              : AppTexts.lunar(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final Widget right = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _countdownLabel(context),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.moss,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(item.nextDate),
                  style: theme.textTheme.bodyMedium,
                ),
                if (item.record.type == EventType.birthday &&
                    item.occurrenceNumber != null)
                  Text(
                    AppTexts.ageYears(context, item.occurrenceNumber!),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            );

            final PopupMenuButton<String> menu = PopupMenuButton<String>(
              onSelected: (String value) async {
                if (value == 'delete') {
                  await ref
                      .read(eventRepositoryProvider)
                      .delete(item.record.id);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(AppTexts.delete(context)),
                ),
              ],
            );

            if (constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      icon,
                      const SizedBox(width: 12),
                      main,
                      menu,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: right),
                ],
              );
            }

            return Row(
              children: <Widget>[
                icon,
                const SizedBox(width: 16),
                main,
                const SizedBox(width: 10),
                right,
                menu,
              ],
            );
          },
        ),
      ),
    );
  }

  String _countdownLabel(BuildContext context) {
    if (item.isToday) {
      return AppTexts.today(context);
    }
    if (item.daysUntil == 1) {
      return AppTexts.tomorrow(context);
    }
    return AppTexts.inDays(context, item.daysUntil);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.blush.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 36,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppTexts.startHint(context),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppTexts.addFirst(context)),
          ),
        ],
      ),
    );
  }
}
