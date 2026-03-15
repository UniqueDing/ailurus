import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/events/domain/occurrence_calculator.dart';
import 'package:ailurus/features/settings/data/caldav_sync_service.dart';
import 'package:ailurus/l10n/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';

class DateSelectors extends StatelessWidget {
  const DateSelectors({
    super.key,
    required this.calendarType,
    required this.sourceYear,
    required this.sourceMonth,
    required this.sourceDay,
    required this.isLeapMonth,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onDayChanged,
  });

  final CalendarType calendarType;
  final int? sourceYear;
  final int sourceMonth;
  final int sourceDay;
  final bool isLeapMonth;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;

  @override
  Widget build(BuildContext context) {
    final Widget yearField = DropdownField<int?>(
      label: AppTexts.yearOptional(context),
      value: sourceYear,
      items: <DropdownMenuItem<int?>>[
        DropdownMenuItem<int?>(
          value: null,
          child: Text(AppTexts.unknown(context)),
        ),
        ...List<DropdownMenuItem<int?>>.generate(121, (int index) {
          final int year = DateTime.now().year + 20 - index;
          final String yearLabel = calendarType == CalendarType.chineseLunar
              ? (AppTexts.isZh(context)
                    ? '$year（${LunarYear.fromYear(year).getGanZhi()}年）'
                    : '$year (${LunarYear.fromYear(year).getGanZhi()})')
              : '$year';
          return DropdownMenuItem<int?>(value: year, child: Text(yearLabel));
        }),
      ],
      onChanged: onYearChanged,
    );

    final Widget monthField = DropdownField<int>(
      label: AppTexts.month(context),
      value: calendarType == CalendarType.chineseLunar
          ? (isLeapMonth ? -sourceMonth : sourceMonth)
          : sourceMonth,
      items: _monthItems(context),
      onChanged: (int? value) {
        if (value != null) {
          onMonthChanged(value);
        }
      },
    );

    final Widget dayField = DropdownField<int>(
      label: AppTexts.day(context),
      value: sourceDay,
      items: List<DropdownMenuItem<int>>.generate(
        _maxDayCount(),
        (int index) => DropdownMenuItem<int>(
          value: index + 1,
          child: Text(
            calendarType == CalendarType.chineseLunar
                ? LunarCn.day(index + 1)
                : '${index + 1}',
          ),
        ),
      ),
      onChanged: (int? value) {
        if (value != null) {
          onDayChanged(value);
        }
      },
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: <Widget>[
              yearField,
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: monthField),
                  const SizedBox(width: 12),
                  Expanded(child: dayField),
                ],
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: yearField),
            const SizedBox(width: 12),
            Expanded(child: monthField),
            const SizedBox(width: 12),
            Expanded(child: dayField),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<int>> _monthItems(BuildContext context) {
    if (calendarType == CalendarType.gregorian) {
      return List<DropdownMenuItem<int>>.generate(
        12,
        (int index) => DropdownMenuItem<int>(
          value: index + 1,
          child: Text('${index + 1}'),
        ),
      );
    }

    final int year = sourceYear ?? DateTime.now().year;
    final List<LunarMonth> months = LunarYear.fromYear(year).getMonthsInYear();
    return months
        .map(
          (LunarMonth month) => DropdownMenuItem<int>(
            value: month.getMonth(),
            child: Text(
              LunarCn.month(month.getMonth().abs(), leap: month.isLeap()),
            ),
          ),
        )
        .toList(growable: false);
  }

  int _maxDayCount() {
    if (calendarType == CalendarType.gregorian) {
      return 31;
    }
    final int year = sourceYear ?? DateTime.now().year;
    final int token = isLeapMonth ? -sourceMonth : sourceMonth;
    final LunarMonth? month = LunarMonth.fromYm(year, token);
    return month?.getDayCount() ?? 30;
  }
}

class ReminderSelector extends StatelessWidget {
  const ReminderSelector({
    super.key,
    required this.selectedOffsets,
    required this.onChanged,
  });

  final Set<int> selectedOffsets;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<_ReminderOption> options = <_ReminderOption>[
      _ReminderOption(0, AppTexts.sameDayReminder(context)),
      _ReminderOption(1, AppTexts.oneDayBeforeReminder(context)),
      _ReminderOption(3, AppTexts.reminderThreeDays(context)),
      _ReminderOption(7, AppTexts.reminderOneWeek(context)),
    ];

    Set<int> toggle(int offset) {
      final Set<int> next = selectedOffsets.toSet();
      if (next.contains(offset)) {
        next.remove(offset);
      } else {
        next.add(offset);
      }
      return next;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTexts.reminderSchedule(context),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => FilterChip(
                  selected: selectedOffsets.contains(option.offset),
                  label: Text(option.label),
                  onSelected: (_) => onChanged(toggle(option.offset)),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ReminderOption {
  const _ReminderOption(this.offset, this.label);

  final int offset;
  final String label;
}

class PolicySelectors extends StatelessWidget {
  const PolicySelectors({
    super.key,
    required this.calendarType,
    required this.showLeapMonthPolicy,
    required this.showLunarMissingDayPolicy,
    required this.showFeb29Policy,
    required this.lunarLeapMonthPolicy,
    required this.lunarMissingDayPolicy,
    required this.feb29Policy,
    required this.onLunarLeapMonthPolicyChanged,
    required this.onLunarMissingDayPolicyChanged,
    required this.onFeb29PolicyChanged,
  });

  final CalendarType calendarType;
  final bool showLeapMonthPolicy;
  final bool showLunarMissingDayPolicy;
  final bool showFeb29Policy;
  final LunarLeapMonthPolicy lunarLeapMonthPolicy;
  final LunarMissingDayPolicy lunarMissingDayPolicy;
  final Feb29Policy feb29Policy;
  final ValueChanged<LunarLeapMonthPolicy> onLunarLeapMonthPolicyChanged;
  final ValueChanged<LunarMissingDayPolicy> onLunarMissingDayPolicyChanged;
  final ValueChanged<Feb29Policy> onFeb29PolicyChanged;

  @override
  Widget build(BuildContext context) {
    final bool isZh = AppTexts.isZh(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isZh ? '日期规则' : 'Date rules',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (showLeapMonthPolicy) ...<Widget>[
          DropdownField<LunarLeapMonthPolicy>(
            label: isZh ? '闰月缺失处理' : 'Missing leap month policy',
            value: lunarLeapMonthPolicy,
            items: LunarLeapMonthPolicy.values
                .map(
                  (value) => DropdownMenuItem<LunarLeapMonthPolicy>(
                    value: value,
                    child: Text(_lunarLeapMonthPolicyLabel(context, value)),
                  ),
                )
                .toList(growable: false),
            onChanged: (LunarLeapMonthPolicy? value) {
              if (value != null) {
                onLunarLeapMonthPolicyChanged(value);
              }
            },
          ),
        ],
        if (showLeapMonthPolicy && showLunarMissingDayPolicy)
          const SizedBox(height: 12),
        if (showLunarMissingDayPolicy) ...<Widget>[
          const SizedBox(height: 12),
          DropdownField<LunarMissingDayPolicy>(
            label: isZh ? '农历日期缺失处理' : 'Missing lunar day policy',
            value: lunarMissingDayPolicy,
            items: LunarMissingDayPolicy.values
                .map(
                  (value) => DropdownMenuItem<LunarMissingDayPolicy>(
                    value: value,
                    child: Text(_lunarMissingDayPolicyLabel(context, value)),
                  ),
                )
                .toList(growable: false),
            onChanged: (LunarMissingDayPolicy? value) {
              if (value != null) {
                onLunarMissingDayPolicyChanged(value);
              }
            },
          ),
        ],
        if ((showLeapMonthPolicy || showLunarMissingDayPolicy) &&
            showFeb29Policy) ...<Widget>[const SizedBox(height: 12)],
        if (showFeb29Policy)
          DropdownField<Feb29Policy>(
            label: isZh ? '2月29日平年处理' : 'Feb 29 policy',
            value: feb29Policy,
            items: Feb29Policy.values
                .map(
                  (value) => DropdownMenuItem<Feb29Policy>(
                    value: value,
                    child: Text(_feb29PolicyLabel(context, value)),
                  ),
                )
                .toList(growable: false),
            onChanged: (Feb29Policy? value) {
              if (value != null) {
                onFeb29PolicyChanged(value);
              }
            },
          ),
      ],
    );
  }

  String _lunarLeapMonthPolicyLabel(
    BuildContext context,
    LunarLeapMonthPolicy policy,
  ) {
    final bool isZh = AppTexts.isZh(context);
    return switch (policy) {
      LunarLeapMonthPolicy.regularMonth =>
        isZh ? '按同名平月（不过闰）' : 'Use regular month',
      LunarLeapMonthPolicy.strict => isZh ? '严格跳过该年' : 'Strict (skip year)',
      LunarLeapMonthPolicy.nextMonth => isZh ? '顺延到下个月' : 'Move to next month',
    };
  }

  String _lunarMissingDayPolicyLabel(
    BuildContext context,
    LunarMissingDayPolicy policy,
  ) {
    final bool isZh = AppTexts.isZh(context);
    return switch (policy) {
      LunarMissingDayPolicy.previousDay =>
        isZh ? '用当月最后一天' : 'Use last day of month',
      LunarMissingDayPolicy.skipYear => isZh ? '跳过该年' : 'Skip this year',
      LunarMissingDayPolicy.nextMonthFirst =>
        isZh ? '顺延到下月初一' : 'Move to next month day 1',
    };
  }

  String _feb29PolicyLabel(BuildContext context, Feb29Policy policy) {
    final bool isZh = AppTexts.isZh(context);
    return switch (policy) {
      Feb29Policy.feb28 => isZh ? '平年按2月28日' : 'Use Feb 28',
      Feb29Policy.march1 => isZh ? '平年按3月1日' : 'Use Mar 1',
      Feb29Policy.strictLeapOnly => isZh ? '仅闰年提醒' : 'Leap years only',
    };
  }
}

class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            isExpanded: true,
            menuMaxHeight: 320,
            borderRadius: BorderRadius.circular(18),
            decoration: InputDecoration(labelText: label),
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

class PreviewCard extends StatefulWidget {
  const PreviewCard({
    super.key,
    required this.record,
    this.fillAvailableHeight = false,
  });

  final EventRecord record;
  final bool fillAvailableHeight;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  static const bool _useSplitPreviewCards = true;

  late final ScrollController _payloadScrollController;
  int _previewTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _payloadScrollController = ScrollController();
  }

  @override
  void dispose() {
    _payloadScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String caldavPayload = CaldavSyncService().buildPreviewPayload(
      widget.record,
    );
    EventOccurrence? occurrence;
    try {
      occurrence = const OccurrenceCalculator().describe(
        widget.record,
        DateTime.now(),
      );
    } on InvalidLunarDateException {
      occurrence = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _InlinePreviewTab(
                  label: AppTexts.cardTab(context),
                  selected: _previewTabIndex == 0,
                  onTap: () {
                    setState(() {
                      _previewTabIndex = 0;
                    });
                  },
                ),
                const SizedBox(width: 12),
                _InlinePreviewTab(
                  label: 'ICS',
                  selected: _previewTabIndex == 1,
                  onTap: () {
                    setState(() {
                      _previewTabIndex = 1;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.fillAvailableHeight)
              Expanded(
                child: _previewTabIndex == 0
                    ? SingleChildScrollView(
                        child: _buildCardPreview(context, theme, occurrence),
                      )
                    : _buildCaldavPreview(context, theme, caldavPayload),
              )
            else
              SizedBox(
                height: 320,
                child: _previewTabIndex == 0
                    ? SingleChildScrollView(
                        child: _buildCardPreview(context, theme, occurrence),
                      )
                    : _buildCaldavPreview(context, theme, caldavPayload),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPreview(
    BuildContext context,
    ThemeData theme,
    EventOccurrence? occurrence,
  ) {
    if (_useSplitPreviewCards) {
      return _buildCardPreviewSplit(context, theme, occurrence);
    }
    return _buildCardPreviewLegacy(context, theme, occurrence);
  }

  Widget _buildCardPreviewSplit(
    BuildContext context,
    ThemeData theme,
    EventOccurrence? occurrence,
  ) {
    final EventRecord record = widget.record;
    final List<String> reminderLabels = _reminderLabels(context, record);

    final List<Widget> basicChildren = <Widget>[
      Text(record.displayTitle, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _metaChip(
            context,
            record.type == EventType.birthday
                ? AppTexts.birthday(context)
                : AppTexts.anniversary(context),
          ),
          _metaChip(
            context,
            record.calendarType == CalendarType.gregorian
                ? AppTexts.gregorian(context)
                : AppTexts.lunar(context),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _metaLine(
        context,
        AppTexts.dateSource(context),
        _sourceDateText(context),
      ),
      if (record.type == EventType.birthday && record.personGender != null)
        _metaLine(
          context,
          AppTexts.gender(context),
          AppTexts.personGender(context, record.personGender!),
        ),
      if (record.type == EventType.birthday &&
          record.personRelationship != null)
        _metaLine(
          context,
          AppTexts.relationship(context),
          AppTexts.personRelationship(context, record.personRelationship!),
        ),
      if ((record.note ?? '').trim().isNotEmpty)
        _metaLine(context, AppTexts.notes(context), record.note!.trim()),
    ];

    final List<Widget> timeChildren = <Widget>[
      if (occurrence != null) ...<Widget>[
        Text(
          DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(occurrence.nextDate),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          occurrence.isToday
              ? AppTexts.happensToday(context)
              : AppTexts.inDays(context, occurrence.daysUntil),
          style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.moss),
        ),
      ] else
        Text(
          AppTexts.invalidLunarCombination(context),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.red.shade700,
          ),
        ),
      if (reminderLabels.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        _metaLine(
          context,
          AppTexts.reminders(context),
          reminderLabels.join(' / '),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _previewGroupCard(context, AppTexts.identity(context), basicChildren),
        const SizedBox(height: 12),
        _previewGroupCard(
          context,
          AppTexts.nextOccurrence(context),
          timeChildren,
        ),
      ],
    );
  }

  Widget _buildCardPreviewLegacy(
    BuildContext context,
    ThemeData theme,
    EventOccurrence? occurrence,
  ) {
    final EventRecord record = widget.record;
    final List<String> reminderLabels = _reminderLabels(context, record);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(record.displayTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _metaChip(
              context,
              record.type == EventType.birthday
                  ? AppTexts.birthday(context)
                  : AppTexts.anniversary(context),
            ),
            _metaChip(
              context,
              record.calendarType == CalendarType.gregorian
                  ? AppTexts.gregorian(context)
                  : AppTexts.lunar(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _metaLine(
          context,
          AppTexts.dateSource(context),
          _sourceDateText(context),
        ),
        if (record.type == EventType.birthday && record.personGender != null)
          _metaLine(
            context,
            AppTexts.gender(context),
            AppTexts.personGender(context, record.personGender!),
          ),
        if (record.type == EventType.birthday &&
            record.personRelationship != null)
          _metaLine(
            context,
            AppTexts.relationship(context),
            AppTexts.personRelationship(context, record.personRelationship!),
          ),
        if (reminderLabels.isNotEmpty)
          _metaLine(
            context,
            AppTexts.reminders(context),
            reminderLabels.join(' / '),
          ),
        if ((record.note ?? '').trim().isNotEmpty)
          _metaLine(context, AppTexts.notes(context), record.note!.trim()),
        const SizedBox(height: 16),
        Text(
          AppTexts.nextOccurrence(context),
          style: theme.textTheme.bodyMedium,
        ),
        if (occurrence != null) ...<Widget>[
          Text(
            DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).format(occurrence.nextDate),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            occurrence.isToday
                ? AppTexts.happensToday(context)
                : AppTexts.inDays(context, occurrence.daysUntil),
            style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.moss),
          ),
        ] else
          Text(
            AppTexts.invalidLunarCombination(context),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.red.shade700,
            ),
          ),
      ],
    );
  }

  Widget _previewGroupCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.12 : 0.05,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, String text) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _metaLine(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceDateText(BuildContext context) {
    final EventRecord record = widget.record;
    final String year =
        record.sourceYear?.toString() ?? AppTexts.unknown(context);
    if (record.calendarType == CalendarType.gregorian) {
      return '$year-${record.sourceMonth}-${record.sourceDay}';
    }
    return '${AppTexts.isZh(context) ? '农历' : 'Lunar'} $year · ${LunarCn.month(record.sourceMonth, leap: record.isLeapMonth)} ${LunarCn.day(record.sourceDay)}';
  }

  List<String> _reminderLabels(BuildContext context, EventRecord record) {
    final List<int> offsets = record.reminderPolicy.offsetsInDays.toList()
      ..sort();
    return offsets
        .map((offset) {
          return switch (offset) {
            0 => AppTexts.sameDayReminder(context),
            1 => AppTexts.oneDayBeforeReminder(context),
            3 => AppTexts.reminderThreeDays(context),
            7 => AppTexts.reminderOneWeek(context),
            _ => '$offset${AppTexts.isZh(context) ? ' 天前' : 'd before'}',
          };
        })
        .toList(growable: false);
  }

  Widget _buildCaldavPreview(
    BuildContext context,
    ThemeData theme,
    String caldavPayload,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.88 : 0.72,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Scrollbar(
            controller: _payloadScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _payloadScrollController,
              primary: false,
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 24,
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    caldavPayload,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InlinePreviewTab extends StatelessWidget {
  const _InlinePreviewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle base =
        theme.textTheme.titleMedium ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
    final Color color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: base.copyWith(
            color: color,
            fontSize: selected ? (base.fontSize ?? 16) + 1 : base.fontSize,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class PreviewRail extends StatelessWidget {
  const PreviewRail({
    super.key,
    required this.record,
    this.fillAvailableHeight = true,
  });

  final EventRecord record;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[AppTheme.moss, AppTheme.copper],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SizedBox.expand(
        child: PreviewCard(
          record: record,
          fillAvailableHeight: fillAvailableHeight,
        ),
      ),
    );
  }
}
