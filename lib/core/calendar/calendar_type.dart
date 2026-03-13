enum CalendarType { gregorian, chineseLunar }

extension CalendarTypeX on CalendarType {
  String get label {
    return switch (this) {
      CalendarType.gregorian => 'Gregorian',
      CalendarType.chineseLunar => 'Chinese Lunar',
    };
  }

  String get shortLabel {
    return switch (this) {
      CalendarType.gregorian => 'Solar',
      CalendarType.chineseLunar => 'Lunar',
    };
  }
}
