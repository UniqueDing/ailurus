import 'package:ailurus/features/events/domain/event_models.dart';
import 'package:ailurus/generated/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

class AppTexts {
  static AppLocalizations _l10n(BuildContext context) =>
      AppLocalizations.of(context)!;

  static bool isZh(BuildContext context) {
    return Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
  }

  static String appTitle(BuildContext context) => _l10n(context).appTitle;
  static String settings(BuildContext context) => _l10n(context).settings;
  static String caldav(BuildContext context) => _l10n(context).caldav;
  static String newEvent(BuildContext context) => _l10n(context).newEvent;
  static String addDate(BuildContext context) => _l10n(context).addDate;
  static String birthday(BuildContext context) => _l10n(context).birthday;
  static String anniversary(BuildContext context) => _l10n(context).anniversary;
  static String gregorian(BuildContext context) => _l10n(context).gregorian;
  static String lunar(BuildContext context) => _l10n(context).lunar;
  static String closestDates(BuildContext context) =>
      _l10n(context).closestDates;
  static String today(BuildContext context) => _l10n(context).today;
  static String next30Days(BuildContext context) => _l10n(context).next30Days;
  static String later(BuildContext context) => _l10n(context).later;
  static String tomorrow(BuildContext context) => _l10n(context).tomorrow;
  static String inDays(BuildContext context, int days) =>
      _l10n(context).inDays(days);
  static String startHint(BuildContext context) => _l10n(context).startHint;
  static String addFirst(BuildContext context) => _l10n(context).addFirst;
  static String editDate(BuildContext context) => _l10n(context).editDate;
  static String createDate(BuildContext context) => _l10n(context).createDate;
  static String saveChanges(BuildContext context) => _l10n(context).saveChanges;
  static String identity(BuildContext context) => _l10n(context).identity;
  static String dateSource(BuildContext context) => _l10n(context).dateSource;
  static String reminders(BuildContext context) => _l10n(context).reminders;
  static String name(BuildContext context) => _l10n(context).name;
  static String title(BuildContext context) => _l10n(context).title;
  static String details(BuildContext context) => _l10n(context).details;
  static String notes(BuildContext context) => _l10n(context).notes;
  static String month(BuildContext context) => _l10n(context).month;
  static String day(BuildContext context) => _l10n(context).day;
  static String yearOptional(BuildContext context) =>
      _l10n(context).yearOptional;
  static String unknown(BuildContext context) => _l10n(context).unknown;
  static String preview(BuildContext context) => _l10n(context).preview;
  static String nextOccurrence(BuildContext context) =>
      _l10n(context).nextOccurrence;
  static String happensToday(BuildContext context) =>
      _l10n(context).happensToday;
  static String saveSyncSettings(BuildContext context) =>
      _l10n(context).saveSyncSettings;
  static String serverUrl(BuildContext context) => _l10n(context).serverUrl;
  static String username(BuildContext context) => _l10n(context).username;
  static String password(BuildContext context) => _l10n(context).password;
  static String calendarPath(BuildContext context) =>
      _l10n(context).calendarPath;
  static String saveOk(BuildContext context) => _l10n(context).saveOk;
  static String currentConnection(BuildContext context) =>
      _l10n(context).currentConnection;
  static String noConfig(BuildContext context) => _l10n(context).noConfig;
  static String syncedIds(BuildContext context) => _l10n(context).syncedIds;
  static String lastSync(BuildContext context) => _l10n(context).lastSync;
  static String lastError(BuildContext context) => _l10n(context).lastError;
  static String noSyncYet(BuildContext context) => _l10n(context).noSyncYet;
  static String syncIntro(BuildContext context) => _l10n(context).syncIntro;
  static String passwordMemoryOnly(BuildContext context) =>
      _l10n(context).passwordMemoryOnly;
  static String allowInsecureTls(BuildContext context) =>
      _l10n(context).allowInsecureTls;
  static String allowInsecureTlsHint(BuildContext context) =>
      _l10n(context).allowInsecureTlsHint;
  static String unableLoadEvent(BuildContext context, Object error) =>
      _l10n(context).unableLoadEvent('$error');
  static String unableLoadDates(BuildContext context, Object error) =>
      _l10n(context).unableLoadDates('$error');
  static String titleOrNameRequired(BuildContext context) =>
      _l10n(context).titleOrNameRequired;
  static String sameDayReminder(BuildContext context) =>
      _l10n(context).sameDayReminder;
  static String oneDayBeforeReminder(BuildContext context) =>
      _l10n(context).oneDayBeforeReminder;
  static String reminderThreeDays(BuildContext context) =>
      _l10n(context).reminderThreeDays;
  static String reminderOneWeek(BuildContext context) =>
      _l10n(context).reminderOneWeek;
  static String reminderConfigure(BuildContext context) =>
      _l10n(context).reminderConfigure;
  static String reminderSchedule(BuildContext context) =>
      _l10n(context).reminderSchedule;
  static String birthdayNameRequired(BuildContext context) =>
      _l10n(context).birthdayNameRequired;
  static String anniversaryTitleRequired(BuildContext context) =>
      _l10n(context).anniversaryTitleRequired;
  static String gender(BuildContext context) => _l10n(context).gender;
  static String relationship(BuildContext context) =>
      _l10n(context).relationship;
  static String ageYears(BuildContext context, int age) =>
      _l10n(context).ageYears(age);
  static String eventMissing(BuildContext context) =>
      _l10n(context).eventMissing;
  static String invalidLunar(BuildContext context) =>
      _l10n(context).invalidLunar;
  static String invalidLunarCombination(BuildContext context) =>
      _l10n(context).invalidLunarCombination;
  static String delete(BuildContext context) => _l10n(context).delete;
  static String language(BuildContext context) => _l10n(context).language;
  static String syncNow(BuildContext context) => _l10n(context).syncNow;
  static String syncing(BuildContext context) => _l10n(context).syncing;
  static String syncStatus(BuildContext context) => _l10n(context).syncStatus;
  static String settingsOverview(BuildContext context) =>
      _l10n(context).settingsOverview;
  static String settingsOverviewHint(BuildContext context) =>
      _l10n(context).settingsOverviewHint;
  static String appearance(BuildContext context) => _l10n(context).appearance;
  static String themeMode(BuildContext context) => _l10n(context).themeMode;
  static String themeSystem(BuildContext context) => _l10n(context).themeSystem;
  static String themeLight(BuildContext context) => _l10n(context).themeLight;
  static String themeDark(BuildContext context) => _l10n(context).themeDark;
  static String general(BuildContext context) => _l10n(context).general;
  static String about(BuildContext context) => _l10n(context).about;
  static String aboutApp(BuildContext context) => _l10n(context).aboutApp;
  static String aboutAppDescription(BuildContext context) =>
      _l10n(context).aboutAppDescription;
  static String privacy(BuildContext context) => _l10n(context).privacy;
  static String privacyPlaceholder(BuildContext context) =>
      _l10n(context).privacyPlaceholder;
  static String help(BuildContext context) => _l10n(context).help;
  static String helpPlaceholder(BuildContext context) =>
      _l10n(context).helpPlaceholder;
  static String licenses(BuildContext context) => _l10n(context).licenses;
  static String allTab(BuildContext context) => _l10n(context).allTab;
  static String favoritesTab(BuildContext context) =>
      _l10n(context).favoritesTab;
  static String pinned(BuildContext context) => _l10n(context).pinned;
  static String pin(BuildContext context) => _l10n(context).pin;
  static String unpin(BuildContext context) => _l10n(context).unpin;
  static String favorite(BuildContext context) => _l10n(context).favorite;
  static String unfavorite(BuildContext context) => _l10n(context).unfavorite;
  static String search(BuildContext context) => _l10n(context).search;
  static String searchHint(BuildContext context) => _l10n(context).searchHint;
  static String noSearchResult(BuildContext context) =>
      _l10n(context).noSearchResult;
  static String leapMonth(BuildContext context) => _l10n(context).leapMonth;
  static String caldavPreview(BuildContext context) =>
      _l10n(context).caldavPreview;
  static String caldavPreviewHint(BuildContext context) =>
      _l10n(context).caldavPreviewHint;
  static String cardTab(BuildContext context) => _l10n(context).cardTab;
  static String unsavedChangesTitle(BuildContext context) =>
      _l10n(context).unsavedChangesTitle;
  static String unsavedChangesMessage(BuildContext context) =>
      _l10n(context).unsavedChangesMessage;
  static String keepEditing(BuildContext context) => _l10n(context).keepEditing;
  static String discardChanges(BuildContext context) =>
      _l10n(context).discardChanges;

  static List<String> heroSlogans(BuildContext context) {
    return <String>[
      _l10n(context).heroSlogan,
      _l10n(context).heroSloganAlt1,
      _l10n(context).heroSloganAlt2,
      _l10n(context).heroSloganAlt3,
    ];
  }

  static String heroSloganByIndex(BuildContext context, int index) {
    final List<String> slogans = heroSlogans(context);
    if (slogans.isEmpty) {
      return '';
    }
    return slogans[index % slogans.length];
  }

  static String languageName(BuildContext context, String code) {
    return switch (code) {
      'zh' => _l10n(context).languageChinese,
      'ja' => _l10n(context).languageJapanese,
      'ko' => _l10n(context).languageKorean,
      _ => _l10n(context).languageEnglish,
    };
  }

  static String personGender(BuildContext context, PersonGender gender) {
    return switch (gender) {
      PersonGender.unspecified => _l10n(context).genderUnspecified,
      PersonGender.male => _l10n(context).genderMale,
      PersonGender.female => _l10n(context).genderFemale,
      PersonGender.other => _l10n(context).genderOther,
    };
  }

  static String personRelationship(
    BuildContext context,
    PersonRelationship relation,
  ) {
    return switch (relation) {
      PersonRelationship.family => _l10n(context).relationshipFamily,
      PersonRelationship.partner => _l10n(context).relationshipPartner,
      PersonRelationship.friend => _l10n(context).relationshipFriend,
      PersonRelationship.colleague => _l10n(context).relationshipColleague,
      PersonRelationship.classmate => _l10n(context).relationshipClassmate,
      PersonRelationship.other => _l10n(context).relationshipOther,
    };
  }
}

class LunarCn {
  static const List<String> _months = <String>[
    '',
    '正月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '冬月',
    '腊月',
  ];

  static const List<String> _days = <String>[
    '',
    '初一',
    '初二',
    '初三',
    '初四',
    '初五',
    '初六',
    '初七',
    '初八',
    '初九',
    '初十',
    '十一',
    '十二',
    '十三',
    '十四',
    '十五',
    '十六',
    '十七',
    '十八',
    '十九',
    '二十',
    '廿一',
    '廿二',
    '廿三',
    '廿四',
    '廿五',
    '廿六',
    '廿七',
    '廿八',
    '廿九',
    '三十',
  ];

  static String month(int month, {required bool leap}) {
    final int safe = month.clamp(1, 12);
    return '${leap ? '闰' : ''}${_months[safe]}';
  }

  static String day(int day) {
    final int safe = day.clamp(1, 30);
    return _days[safe];
  }
}
