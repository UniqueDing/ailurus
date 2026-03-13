import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/events/domain/occurrence_calculator.dart';
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
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownField<int?>(
                label: AppTexts.yearOptional(context),
                value: sourceYear,
                items: <DropdownMenuItem<int?>>[
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(AppTexts.unknown(context)),
                  ),
                  ...List<DropdownMenuItem<int?>>.generate(90, (int index) {
                    final int year = DateTime.now().year - index;
                    final String yearLabel =
                        calendarType == CalendarType.chineseLunar
                        ? (AppTexts.isZh(context)
                              ? '$year（${LunarYear.fromYear(year).getGanZhi()}年）'
                              : '$year (${LunarYear.fromYear(year).getGanZhi()})')
                        : '$year';
                    return DropdownMenuItem<int?>(
                      value: year,
                      child: Text(yearLabel),
                    );
                  }),
                ],
                onChanged: onYearChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownField<int>(
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownField<int>(
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
              ),
            ),
          ],
        ),
      ],
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
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

class PreviewCard extends StatelessWidget {
  const PreviewCard({super.key, required this.record});

  final EventRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    EventOccurrence? occurrence;
    try {
      occurrence = const OccurrenceCalculator().describe(
        record,
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
            Text(
              AppTexts.preview(context),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(record.displayTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  label: Text(
                    record.type == EventType.birthday
                        ? AppTexts.birthday(context)
                        : AppTexts.anniversary(context),
                  ),
                ),
                Chip(
                  label: Text(
                    record.calendarType == CalendarType.gregorian
                        ? AppTexts.gregorian(context)
                        : AppTexts.lunar(context),
                  ),
                ),
              ],
            ),
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.moss,
                ),
              ),
            ] else
              Text(
                AppTexts.invalidLunarCombination(context),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreviewRail extends StatelessWidget {
  const PreviewRail({super.key, required this.record});

  final EventRecord record;

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
      child: PreviewCard(record: record),
    );
  }
}
