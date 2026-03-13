# Ailurus

A cross-platform Flutter app for birthdays and anniversaries with Gregorian and Chinese lunar support.

## Project Structure

```
lib/
  app/                  # app bootstrap, router, theme
  core/                 # shared low-level types/utilities
  features/
    events/             # domain/data/presentation for records and occurrences
    settings/           # sync settings and CalDAV integration UI/service
  l10n/                 # ARB resources + generated localization + AppTexts wrapper
```

## What To Edit

- Edit localization text in `lib/l10n/app_*.arb`
- Do not manually edit generated localization files:
  - `lib/generated/l10n/app_localizations.dart`
  - `lib/generated/l10n/app_localizations_*.dart`

## Common Commands

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run -d linux
```

## Notes On Cleanup

- Build caches (`.dart_tool/`, `build/`) are generated artifacts.
- The active localization helper is `lib/l10n/app_texts.dart`.
