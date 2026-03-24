import 'dart:math';

import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/settings/application/sync_settings_controller.dart';
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
    final SyncUiState syncUiState = ref.watch(syncSettingsProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 980;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

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
            tooltip: AppTexts.syncNow(context),
            onPressed: syncUiState.isSyncing
                ? null
                : () async {
                    await ref.read(syncSettingsProvider.notifier).syncNow();
                    if (!context.mounted) {
                      return;
                    }
                    final SyncUiState latest = ref.read(syncSettingsProvider);
                    final String message =
                        latest.statusMessage ??
                        (AppTexts.isZh(context) ? '同步已完成。' : 'Sync finished.');
                    final bool hasError =
                        latest.settings.lastSyncError?.isNotEmpty == true;
                    final ScaffoldMessengerState messenger =
                        ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: <Widget>[
                            Icon(
                              hasError
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: hasError
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(message)),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: hasError
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer,
                        showCloseIcon: true,
                        closeIconColor: hasError
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
            icon: syncUiState.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;
          final double blobSize = width * 0.56;
          final double auraSize = (height * 0.42).clamp(180, 460).toDouble();

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        theme.scaffoldBackgroundColor,
                        colorScheme.surface,
                        colorScheme.primary.withValues(
                          alpha: isDark ? 0.14 : 0.08,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -blobSize * 0.22,
                top: -blobSize * 0.28,
                child: IgnorePointer(
                  child: Container(
                    width: blobSize,
                    height: blobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.09 : 0.07,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -auraSize * 0.44,
                bottom: -auraSize * 0.34,
                child: IgnorePointer(
                  child: Container(
                    width: auraSize,
                    height: auraSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.secondary.withValues(
                        alpha: isDark ? 0.08 : 0.06,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
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
            ],
          );
        },
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
    final ColorScheme colorScheme = theme.colorScheme;
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
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onFavoritesOnlyChanged(!favoritesOnly),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          constraints: const BoxConstraints(minHeight: 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: favoritesOnly
                                ? colorScheme.primary.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: favoritesOnly
                                  ? colorScheme.primary.withValues(alpha: 0.52)
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
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 16,
                                color: favoritesOnly
                                    ? colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.55,
                                      ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppTexts.favorite(context),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: favoritesOnly
                                      ? colorScheme.primary
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
    final ColorScheme colorScheme = theme.colorScheme;

    final Widget dateBadge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        dateLabel,
        style:
            (compact
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium)
                ?.copyWith(color: colorScheme.onPrimary),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 36),
        gradient: LinearGradient(
          colors: <Color>[
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.9),
            colorScheme.secondary,
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
                    ?.copyWith(color: colorScheme.onPrimary),
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
    final ColorScheme colorScheme = theme.colorScheme;
    final Color favoriteToneStrong = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.34 : 0.26),
      const Color(0xFFD32F2F),
    );
    final Color favoriteToneSoft = Color.alphaBlend(
      colorScheme.secondary.withValues(alpha: isDark ? 0.3 : 0.2),
      const Color(0xFFEF5350),
    );
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: <Widget>[
              Ink(
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
                                  ? colorScheme.secondaryContainer.withValues(
                                      alpha: 0.48,
                                    )
                                  : colorScheme.secondaryContainer.withValues(
                                      alpha: 0.8,
                                    ))
                            : (isDark
                                  ? colorScheme.primaryContainer.withValues(
                                      alpha: 0.5,
                                    )
                                  : colorScheme.primaryContainer.withValues(
                                      alpha: 0.82,
                                    )),
                      ),
                      child: Icon(
                        item.record.type == EventType.birthday
                            ? Icons.cake_rounded
                            : Icons.favorite_rounded,
                        color: item.record.type == EventType.birthday
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    );

                    final Widget main = Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _nameWidget(theme),
                          if (_ageWidget(context, theme)
                              case final Widget ageWidget) ...<Widget>[
                            const SizedBox(height: 2),
                            ageWidget,
                          ],
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
                            color: colorScheme.primary,
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
              if (item.record.isFavorite)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: _TopRightTriangleClipper(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              favoriteToneSoft,
                              favoriteToneStrong,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

  Widget _nameWidget(ThemeData theme) {
    return Text(
      item.record.displayTitle,
      style: theme.textTheme.titleLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _ageWidget(BuildContext context, ThemeData theme) {
    if (item.record.type != EventType.birthday ||
        item.occurrenceNumber == null) {
      return null;
    }
    return Text(
      AppTexts.ageYears(context, item.occurrenceNumber!),
      style: theme.textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
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

class _TopRightTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 36,
              color: colorScheme.onSecondaryContainer,
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
