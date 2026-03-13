import 'dart:math';

import 'package:ailurus/app/theme/app_theme.dart';
import 'package:ailurus/core/calendar/calendar_type.dart';
import 'package:ailurus/features/events/application/providers.dart';
import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/features/events/domain/occurrence_calculator.dart';
import 'package:ailurus/features/events/presentation/widgets/editor_widgets.dart';
import 'package:ailurus/l10n/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lunar/lunar.dart';

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({super.key, this.eventId});

  final String? eventId;

  bool get isEditing => eventId != null;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  EventType _type = EventType.birthday;
  CalendarType _calendarType = CalendarType.gregorian;
  int? _sourceYear;
  int _sourceMonth = 1;
  int _sourceDay = 1;
  bool _isLeapMonth = false;
  Set<int> _reminderOffsets = <int>{0};
  PersonGender _personGender = PersonGender.unspecified;
  PersonRelationship _personRelationship = PersonRelationship.family;
  LunarLeapMonthPolicy _lunarLeapMonthPolicy =
      LunarLeapMonthPolicy.regularMonth;
  LunarMissingDayPolicy _lunarMissingDayPolicy =
      LunarMissingDayPolicy.previousDay;
  Feb29Policy _feb29Policy = Feb29Policy.feb28;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _personController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<EventRecord?> existing = widget.isEditing
        ? ref.watch(eventByIdProvider(widget.eventId!))
        : const AsyncValue<EventRecord?>.data(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? AppTexts.editDate(context)
              : AppTexts.createDate(context),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppTheme.cream,
              AppTheme.cream,
              AppTheme.sand.withValues(alpha: 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: existing.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) =>
                Center(child: Text(AppTexts.unableLoadEvent(context, error))),
            data: (EventRecord? record) {
              if (!_initialized) {
                _hydrate(record);
              }
              final bool wide = MediaQuery.sizeOf(context).width >= 1100;
              final bool showRuleOptions =
                  (_calendarType == CalendarType.chineseLunar &&
                      (_isLeapMonth || _sourceDay == 30)) ||
                  (_calendarType == CalendarType.gregorian &&
                      _sourceMonth == 2 &&
                      _sourceDay == 29);
              final bool showLeapMonthPolicy =
                  _calendarType == CalendarType.chineseLunar && _isLeapMonth;
              final bool showLunarMissingDayPolicy =
                  _calendarType == CalendarType.chineseLunar &&
                  _sourceDay == 30;
              final bool showFeb29Policy =
                  _calendarType == CalendarType.gregorian &&
                  _sourceMonth == 2 &&
                  _sourceDay == 29;

              final Widget form = Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTexts.identity(context),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<EventType>(
                              segments: EventType.values
                                  .map(
                                    (value) => ButtonSegment<EventType>(
                                      value: value,
                                      label: Text(
                                        value == EventType.birthday
                                            ? AppTexts.birthday(context)
                                            : AppTexts.anniversary(context),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              selected: <EventType>{_type},
                              onSelectionChanged: (Set<EventType> values) =>
                                  setState(() => _type = values.first),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _personController,
                              decoration: InputDecoration(
                                labelText: AppTexts.name(context),
                              ),
                              validator: (String? value) {
                                if (_type == EventType.birthday &&
                                    (value ?? '').trim().isEmpty) {
                                  return AppTexts.birthdayNameRequired(context);
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_type == EventType.anniversary)
                              TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: AppTexts.title(context),
                                ),
                                validator: (String? value) {
                                  if ((value ?? '').trim().isEmpty &&
                                      _personController.text.trim().isEmpty) {
                                    return AppTexts.titleOrNameRequired(
                                      context,
                                    );
                                  }
                                  return null;
                                },
                              ),
                            if (_type == EventType.birthday) ...<Widget>[
                              DropdownField<PersonGender>(
                                label: AppTexts.gender(context),
                                value: _personGender,
                                items: PersonGender.values
                                    .map(
                                      (value) => DropdownMenuItem<PersonGender>(
                                        value: value,
                                        child: Text(
                                          AppTexts.personGender(context, value),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (PersonGender? value) {
                                  if (value != null) {
                                    setState(() => _personGender = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownField<PersonRelationship>(
                                label: AppTexts.relationship(context),
                                value: _personRelationship,
                                items: PersonRelationship.values
                                    .map(
                                      (value) =>
                                          DropdownMenuItem<PersonRelationship>(
                                            value: value,
                                            child: Text(
                                              AppTexts.personRelationship(
                                                context,
                                                value,
                                              ),
                                            ),
                                          ),
                                    )
                                    .toList(growable: false),
                                onChanged: (PersonRelationship? value) {
                                  if (value != null) {
                                    setState(() => _personRelationship = value);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTexts.dateSource(context),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<CalendarType>(
                              segments: CalendarType.values
                                  .map(
                                    (value) => ButtonSegment<CalendarType>(
                                      value: value,
                                      label: Text(
                                        value == CalendarType.gregorian
                                            ? AppTexts.gregorian(context)
                                            : AppTexts.lunar(context),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              selected: <CalendarType>{_calendarType},
                              onSelectionChanged: (Set<CalendarType> values) {
                                final CalendarType target = values.first;
                                if (target == _calendarType) {
                                  return;
                                }
                                setState(() {
                                  _switchCalendarType(target);
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DateSelectors(
                              calendarType: _calendarType,
                              sourceYear: _sourceYear,
                              sourceMonth: _sourceMonth,
                              sourceDay: _sourceDay,
                              isLeapMonth: _isLeapMonth,
                              onYearChanged: (int? value) => setState(() {
                                _sourceYear = value;
                                _normalizeLunarSelection();
                              }),
                              onMonthChanged: (int value) => setState(() {
                                _sourceMonth = value.abs();
                                _isLeapMonth = value < 0;
                                _normalizeLunarSelection();
                              }),
                              onDayChanged: (int value) =>
                                  setState(() => _sourceDay = value),
                            ),
                            if (showRuleOptions) ...<Widget>[
                              const SizedBox(height: 16),
                              PolicySelectors(
                                calendarType: _calendarType,
                                showLeapMonthPolicy: showLeapMonthPolicy,
                                showLunarMissingDayPolicy:
                                    showLunarMissingDayPolicy,
                                showFeb29Policy: showFeb29Policy,
                                lunarLeapMonthPolicy: _lunarLeapMonthPolicy,
                                lunarMissingDayPolicy: _lunarMissingDayPolicy,
                                feb29Policy: _feb29Policy,
                                onLunarLeapMonthPolicyChanged:
                                    (LunarLeapMonthPolicy value) => setState(
                                      () => _lunarLeapMonthPolicy = value,
                                    ),
                                onLunarMissingDayPolicyChanged:
                                    (LunarMissingDayPolicy value) => setState(
                                      () => _lunarMissingDayPolicy = value,
                                    ),
                                onFeb29PolicyChanged: (Feb29Policy value) =>
                                    setState(() => _feb29Policy = value),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTexts.reminders(context),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            ReminderSelector(
                              selectedOffsets: _reminderOffsets,
                              onChanged: (Set<int> offsets) {
                                setState(() => _reminderOffsets = offsets);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _noteController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: AppTexts.notes(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!wide) PreviewCard(record: _draftRecord(record)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        widget.isEditing
                            ? AppTexts.saveChanges(context)
                            : AppTexts.createDate(context),
                      ),
                    ),
                  ],
                ),
              );
              if (!wide) {
                return form;
              }

              return Row(
                children: <Widget>[
                  Expanded(flex: 7, child: form),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 20, 20),
                      child: PreviewRail(record: _draftRecord(record)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  EventRecord _draftRecord(EventRecord? existing) {
    final DateTime now = DateTime.now();
    return EventRecord(
      id: existing?.id ?? _randomId(),
      type: _type,
      title: _resolvedTitle(),
      personName: _personController.text.trim().isEmpty
          ? null
          : _personController.text.trim(),
      personGender: _type == EventType.birthday ? _personGender : null,
      personRelationship: _type == EventType.birthday
          ? _personRelationship
          : null,
      calendarType: _calendarType,
      sourceYear: _sourceYear,
      sourceMonth: _sourceMonth,
      sourceDay: _sourceDay,
      isLeapMonth: _isLeapMonth,
      timezone: 'Asia/Shanghai',
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      reminderPolicy: ReminderPolicy(offsetsInDays: _reminderOffsets.toList()),
      lunarLeapMonthPolicy: _lunarLeapMonthPolicy,
      lunarMissingDayPolicy: _lunarMissingDayPolicy,
      feb29Policy: _feb29Policy,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _hydrate(EventRecord? record) {
    _initialized = true;
    if (record == null) {
      return;
    }
    _titleController.text = record.title;
    _personController.text = record.personName ?? '';
    _noteController.text = record.note ?? '';
    _type = record.type;
    _personGender = record.personGender ?? PersonGender.unspecified;
    _personRelationship =
        record.personRelationship ?? PersonRelationship.family;
    _calendarType = record.calendarType;
    _sourceYear = record.sourceYear;
    _sourceMonth = record.sourceMonth;
    _sourceDay = record.sourceDay;
    _isLeapMonth = record.isLeapMonth;
    _reminderOffsets = record.reminderPolicy.offsetsInDays.toSet();
    _lunarLeapMonthPolicy = record.lunarLeapMonthPolicy;
    _lunarMissingDayPolicy = record.lunarMissingDayPolicy;
    _feb29Policy = record.feb29Policy;
    _normalizeLunarSelection();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final EventRecord? existing = widget.isEditing
        ? await ref.read(eventByIdProvider(widget.eventId!).future)
        : null;

    if (widget.isEditing && existing == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppTexts.eventMissing(context))));
      }
      return;
    }

    final EventRecord draft = _draftRecord(existing);
    try {
      const OccurrenceCalculator().describe(draft, DateTime.now());
    } on InvalidLunarDateException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppTexts.invalidLunar(context))));
      }
      return;
    }

    await ref.read(eventRepositoryProvider).save(draft);
    if (mounted) {
      context.pop();
    }
  }

  String _resolvedTitle() {
    if (_type == EventType.birthday &&
        _personController.text.trim().isNotEmpty) {
      return _personController.text.trim();
    }
    if (_titleController.text.trim().isNotEmpty) {
      return _titleController.text.trim();
    }
    if (_personController.text.trim().isNotEmpty) {
      return _personController.text.trim();
    }
    return _type.label;
  }

  String _randomId() {
    final Random random = Random();
    return random.nextInt(1 << 32).toRadixString(16);
  }

  void _normalizeLunarSelection() {
    if (_calendarType != CalendarType.chineseLunar) {
      return;
    }

    final int year = _sourceYear ?? DateTime.now().year;
    final List<LunarMonth> months = LunarYear.fromYear(year).getMonthsInYear();
    if (months.isEmpty) {
      return;
    }

    int token = _isLeapMonth ? -_sourceMonth : _sourceMonth;
    final bool exists = months.any((month) => month.getMonth() == token);
    if (!exists) {
      token = months.first.getMonth();
    }

    _sourceMonth = token.abs();
    _isLeapMonth = token < 0;

    final LunarMonth? selected = LunarMonth.fromYm(year, token);
    final int maxDay = selected?.getDayCount() ?? 30;
    if (_sourceDay > maxDay) {
      _sourceDay = maxDay;
    }
  }

  void _switchCalendarType(CalendarType target) {
    if (_calendarType == target) {
      return;
    }

    if (_calendarType == CalendarType.gregorian &&
        target == CalendarType.chineseLunar) {
      final int year = _sourceYear ?? DateTime.now().year;
      final DateTime solarDate = _safeGregorianDate(
        year,
        _sourceMonth,
        _sourceDay,
      );
      final Lunar lunar = Solar.fromYmd(
        solarDate.year,
        solarDate.month,
        solarDate.day,
      ).getLunar();
      final int lunarMonth = lunar.getMonth();

      _calendarType = target;
      if (_sourceYear != null) {
        _sourceYear = lunar.getYear();
      }
      _sourceMonth = lunarMonth.abs();
      _isLeapMonth = lunarMonth < 0;
      _sourceDay = lunar.getDay();
      return;
    }

    if (_calendarType == CalendarType.chineseLunar &&
        target == CalendarType.gregorian) {
      _normalizeLunarSelection();
      final int year = _sourceYear ?? DateTime.now().year;
      final int token = _isLeapMonth ? -_sourceMonth : _sourceMonth;

      try {
        final Solar solar = Lunar.fromYmd(year, token, _sourceDay).getSolar();
        _calendarType = target;
        if (_sourceYear != null) {
          _sourceYear = solar.getYear();
        }
        _sourceMonth = solar.getMonth();
        _sourceDay = solar.getDay();
        _isLeapMonth = false;
      } catch (_) {
        _calendarType = target;
        _isLeapMonth = false;
        _sourceDay = _sourceDay.clamp(1, 31);
      }
    }
  }

  DateTime _safeGregorianDate(int year, int month, int day) {
    final int safeMonth = month.clamp(1, 12);
    final int maxDay = safeMonth == DateTime.december
        ? 31
        : DateTime(
            year,
            safeMonth + 1,
            1,
          ).subtract(const Duration(days: 1)).day;
    final int safeDay = day.clamp(1, maxDay);
    return DateTime(year, safeMonth, safeDay);
  }
}
