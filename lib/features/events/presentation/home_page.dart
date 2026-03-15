import 'dart:math';

import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/l10n/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final int _sloganIndex;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _favoritesOnly = false;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _sloganIndex = Random().nextInt(10000);
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _searchFocusNode.unfocus();
      }
    });
    if (_searchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<EventOccurrence>> occurrences = ref.watch(
      sortedOccurrencesProvider,
    );
    final bool wide = MediaQuery.sizeOf(context).width >= 980;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _searchExpanded
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: AppTexts.searchHint(context),
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            : Text(AppTexts.appTitle(context)),
        actions: <Widget>[
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _searchExpanded ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          // Add button moved to bottom-left FAB for all sizes.
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/event/new'),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? <Color>[
                    const Color(0xFF161C1A),
                    const Color(0xFF1D2723),
                    const Color(0xFF161C1A),
                  ]
                : <Color>[
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 7,
                        child: _EventsPanel(
                          occurrences: occurrences,
                          favoritesOnly: _favoritesOnly,
                          onFavoritesOnlyChanged: (bool value) {
                            setState(() {
                              _favoritesOnly = value;
                            });
                          },
                          searchQuery: _searchController.text,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: _HeroPanel(
                          dateLabel: _todayLabel(context),
                          sloganIndex: _sloganIndex,
                          compact: false,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _HeroPanel(
                        dateLabel: _todayLabel(context),
                        sloganIndex: _sloganIndex,
                        compact: true,
                      ),
                      const SizedBox(height: 14),
                      _EventsPanel(
                        occurrences: occurrences,
                        favoritesOnly: _favoritesOnly,
                        onFavoritesOnlyChanged: (bool value) {
                          setState(() {
                            _favoritesOnly = value;
                          });
                        },
                        searchQuery: _searchController.text,
                      ),
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
  const _EventsPanel({
    required this.occurrences,
    required this.favoritesOnly,
    required this.onFavoritesOnlyChanged,
    required this.searchQuery,
  });

  final AsyncValue<List<EventOccurrence>> occurrences;
  final bool favoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: occurrences.when(
          data: (List<EventOccurrence> items) {
            if (items.isEmpty) {
              return _EmptyState(onAdd: () => context.push('/event/new'));
            }

            final String query = searchQuery.trim().toLowerCase();
            List<EventOccurrence> filteredAll = List<EventOccurrence>.from(
              items,
            );

            if (query.isNotEmpty) {
              filteredAll = filteredAll.where((EventOccurrence occurrence) {
                final EventRecord record = occurrence.record;
                final String haystack = <String>[
                  record.displayTitle,
                  record.title,
                  record.personName ?? '',
                  record.note ?? '',
                ].join(' ').toLowerCase();
                return haystack.contains(query);
              }).toList();
            }

            final List<EventOccurrence> pinned = filteredAll
                .where((item) => item.record.isPinned)
                .toList();
            final List<EventOccurrence> recentBase = filteredAll
                .where((item) => !item.record.isPinned)
                .toList();
            final List<EventOccurrence> recent = favoritesOnly
                ? recentBase.where((item) => item.record.isFavorite).toList()
                : recentBase;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (pinned.isNotEmpty) ...<Widget>[
                  _Section(title: AppTexts.pinned(context), items: pinned),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      AppTexts.isZh(context) ? '最近事项' : 'Upcoming',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onFavoritesOnlyChanged(!favoritesOnly),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: favoritesOnly
                                ? AppTheme.moss.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: favoritesOnly
                                  ? AppTheme.moss.withValues(alpha: 0.52)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.18,
                                    ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                favoritesOnly
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 16,
                                color: favoritesOnly
                                    ? AppTheme.moss
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.55,
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppTexts.favorite(context),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: favoritesOnly
                                      ? AppTheme.moss
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.55,
                                        ),
                                  fontWeight: favoritesOnly
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recent.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EventCard(item: item),
                  ),
                ),
                if (recent.isNotEmpty) const SizedBox(height: 12),
                if (pinned.isEmpty && recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppTexts.noSearchResult(context),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
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
  const _HeroPanel({
    required this.dateLabel,
    required this.sloganIndex,
    this.compact = false,
  });

  final String dateLabel;
  final int sloganIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget dateBadge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        dateLabel,
        style:
            (compact
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium)
                ?.copyWith(color: Colors.white),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 36),
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
          Align(alignment: Alignment.topLeft, child: dateBadge),
          const SizedBox(height: 18),
          Text(
            AppTexts.heroSloganByIndex(context, sloganIndex),
            style:
                (compact
                        ? theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          )
                        : theme.textTheme.displayMedium)
                    ?.copyWith(color: Colors.white),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
    final bool isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onLongPressStart: (LongPressStartDetails details) {
        _showActionsMenu(context, ref, details.globalPosition);
      },
      onSecondaryTapDown: (TapDownDetails details) {
        _showActionsMenu(context, ref, details.globalPosition);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/event/${item.record.id}'),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: isDark ? 0.96 : 0.86,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.14 : 0.05,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget icon = Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: item.record.type == EventType.birthday
                      ? (isDark
                            ? AppTheme.copper.withValues(alpha: 0.32)
                            : AppTheme.blush.withValues(alpha: 0.78))
                      : (isDark
                            ? AppTheme.moss.withValues(alpha: 0.34)
                            : AppTheme.sand.withValues(alpha: 0.85)),
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
                      _titleWithAge(context),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (_noteText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        _noteText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final Widget right = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _countdownLabel(context),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark ? theme.colorScheme.primary : AppTheme.moss,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.MMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(item.nextDate),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_lunarNextDateText(context)
                      case final String lunarText) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      lunarText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );

              return Row(
                children: <Widget>[
                  icon,
                  const SizedBox(width: 16),
                  main,
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: right,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showActionsMenu(
    BuildContext context,
    WidgetRef ref,
    Offset globalPosition,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final String? action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pin',
          child: Text(
            item.record.isPinned
                ? AppTexts.unpin(context)
                : AppTexts.pin(context),
          ),
        ),
        PopupMenuItem<String>(
          value: 'favorite',
          child: Text(
            item.record.isFavorite
                ? AppTexts.unfavorite(context)
                : AppTexts.favorite(context),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(AppTexts.delete(context)),
        ),
      ],
    );

    if (action == null) {
      return;
    }

    if (action == 'pin') {
      await _togglePinned(ref);
      return;
    }
    if (action == 'favorite') {
      await _toggleFavorite(ref);
      return;
    }
    if (action == 'delete') {
      await ref.read(eventRepositoryProvider).delete(item.record.id);
    }
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

  String get _noteText => item.record.note?.trim() ?? '';

  Future<void> _togglePinned(WidgetRef ref) {
    final EventRecord updated = item.record.copyWith(
      isPinned: !item.record.isPinned,
      updatedAt: DateTime.now(),
    );
    return ref.read(eventRepositoryProvider).save(updated);
  }

  Future<void> _toggleFavorite(WidgetRef ref) {
    final EventRecord updated = item.record.copyWith(
      isFavorite: !item.record.isFavorite,
      updatedAt: DateTime.now(),
    );
    return ref.read(eventRepositoryProvider).save(updated);
  }

  String _titleWithAge(BuildContext context) {
    if (item.record.type == EventType.birthday &&
        item.occurrenceNumber != null) {
      return '${item.record.displayTitle} · ${AppTexts.ageYears(context, item.occurrenceNumber!)}';
    }
    return item.record.displayTitle;
  }

  String? _lunarNextDateText(BuildContext context) {
    if (item.record.calendarType != CalendarType.chineseLunar) {
      return null;
    }
    final Lunar lunar = Solar.fromDate(item.nextDate).getLunar();
    final bool isLeap = lunar.getMonth() < 0;
    if (AppTexts.isZh(context)) {
      return '农历 ${LunarCn.month(lunar.getMonth().abs(), leap: isLeap)}${LunarCn.day(lunar.getDay())}';
    }
    final int month = lunar.getMonth().abs();
    final int day = lunar.getDay();
    final String leap = isLeap ? ' (Leap)' : '';
    return 'Lunar M$month D$day$leap';
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
