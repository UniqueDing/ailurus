# Ailurus

Ailurus is a cross-platform Flutter app for tracking birthdays and anniversaries, with support for both Gregorian dates and Chinese lunar dates. It is designed as a local-first personal calendar utility, with optional CalDAV synchronization for people who want to keep their event data in sync across devices.

## What the app does

Ailurus focuses on a small, opinionated set of personal calendar workflows:

- Create and manage birthdays and anniversaries
- Support both Gregorian and Chinese lunar source dates
- Calculate upcoming occurrences and age/year milestones
- Pin and favorite important events
- Search and browse events from the home screen
- Configure language, theme mode, and color palette
- Sync events with a CalDAV calendar using Ailurus-generated ICS resources

The main user flows are exposed through four routes:

- `/` — home page
- `/event/new` — create event
- `/event/:id` — edit event
- `/settings` — app settings and sync configuration

## Platforms

The repository is set up as a cross-platform Flutter app. It currently includes platform folders for:

- Android
- iOS
- macOS
- Windows
- Linux

## Storage structure

Ailurus is local-first. Even without CalDAV configured, the app can store and manage events locally.

### 1. Local event storage

Event data is persisted as JSON in the app support directory.

- File: `events.json`
- Repository: `lib/features/events/data/event_repository.dart`
- Domain model: `lib/features/events/domain/event_models.dart`

The payload structure is intentionally simple:

```json
{
  "schemaVersion": 1,
  "data": [
    { "...event record json...": true }
  ]
}
```

`EventRepository` keeps an in-memory map of `EventRecord` objects, persists changes atomically via a temporary file rename, and exposes both query and watch-style APIs to the UI.

### 2. Sync settings storage

Sync and appearance settings are also persisted as JSON in the app support directory.

- File: `sync_settings.json`
- Repository: `lib/features/settings/data/sync_settings_repository.dart`
- State model: `lib/features/settings/application/sync_settings_controller.dart`

This file stores things like:

- CalDAV server URL
- Username and password
- Calendar path
- Insecure TLS toggle
- Language code
- Theme mode
- Selected color palette
- Last sync metadata
- Known synced event IDs

### 3. Remote sync storage model

When CalDAV is enabled, Ailurus does not write arbitrary third-party calendar content. Instead, it manages its own ICS resources using a stable naming convention:

- `ailurus-<eventId>.ics`

The ICS shape and sync behavior are documented in:

- `doc/ics-format.md`
- `doc/sync-mechanism.md`

## Sync model

Ailurus uses a local-first, optional two-way CalDAV synchronization model.

At a high level, a sync run does this:

1. Validate CalDAV configuration
2. Perform authentication preflight
3. Discover remote resources with `PROPFIND`
4. Pull remote ICS resources with `GET`
5. Compare local and remote records by event ID and `updatedAt`
6. Upload locally newer records with `PUT`
7. Delete obsolete remote resources with `DELETE`
8. Persist updated sync state locally

Conflict handling is a simplified last-writer-wins strategy based on timestamps. The implementation also includes protection against partial remote reads, so a failed remote fetch does not immediately cause an overwrite or deletion decision.

The sync entry path is:

- `SettingsPage`
- `SyncSettingsNotifier.syncNow()`
- `CaldavSyncService.sync()`

## Architecture overview

The codebase is organized around a small app shell plus feature modules.

```text
lib/
  app/                  # App bootstrap, router, theme
  core/                 # Shared low-level types and utilities
  features/
    events/             # Event domain, persistence, calculations, UI
    settings/           # Sync settings, CalDAV service, settings UI
  generated/            # Generated localization output
  l10n/                 # ARB resources and localization helpers
  main.dart             # Entry point
```

### App layer

- `lib/main.dart` boots Flutter and wraps the app in `ProviderScope`
- `lib/app/app.dart` builds the root `MaterialApp.router`
- `lib/app/router.dart` defines top-level navigation
- `lib/app/theme/` contains theming and color-palette logic

### Events feature

The events feature is split into domain, data, and presentation concerns:

- `domain/`
  - event models
  - calendar semantics
  - occurrence calculation
- `data/`
  - local JSON-backed repository
- `presentation/`
  - home page
  - event editor
  - reusable editor widgets

This is the core product feature: managing event records and turning source dates into upcoming occurrences.

### Settings feature

The settings feature owns both user preferences and synchronization behavior:

- `application/`
  - `SyncSettings`
  - notifier/state transitions
- `data/`
  - settings persistence
  - CalDAV sync service
- `presentation/`
  - settings page and sync controls

This module is where configuration, remote sync, and sync status all come together.

### Localization

Localization is managed through ARB files under `lib/l10n/`, with a small helper wrapper in `lib/l10n/app_texts.dart`.

Do not manually edit generated localization files under `lib/generated/l10n/`.

## Domain model summary

At the center of the app is `EventRecord`, which represents a stored event. It includes information such as:

- Event type (`birthday` or `anniversary`)
- Source calendar (`gregorian` or `chinese lunar`)
- Date parts
- Optional notes
- Pin/favorite state
- Creation and update timestamps

Occurrence calculation is handled separately so that stored source dates and displayed upcoming dates remain decoupled.

## CalDAV and ICS conventions

For interoperability, Ailurus serializes events into calendar resources with:

- Standard ICS/VEVENT fields
- Ailurus-specific `X-AILURUS-*` fields for reversible parsing and sync metadata

That allows the app to preserve app-specific information such as:

- original calendar type
- leap-month state
- pin/favorite state
- created/updated timestamps

If you change ICS generation or parsing rules, update these docs as well:

- `doc/ics-format.md`
- `doc/sync-mechanism.md`

## Development notes

### Common commands

```bash
flutter gen-l10n
flutter analyze
flutter test
flutter run -d linux
```

### What to edit

- Edit visible localization text in `lib/l10n/app_*.arb`
- Do not manually edit generated localization files:
  - `lib/generated/l10n/app_localizations.dart`
  - `lib/generated/l10n/app_localizations_*.dart`

### Practical conventions

- Keep changes small and focused
- Reuse existing patterns in each module
- When adding or removing visible copy, update all supported localization files
- When changing sync or ICS behavior, keep documentation in `doc/` in sync with the implementation

## Current scope

Ailurus is intentionally lightweight. It is not trying to be a general-purpose calendar client. The current architecture is optimized for:

- personal event tracking
- local persistence with simple JSON storage
- optional CalDAV interoperability
- straightforward Flutter feature modules

If you want to extend the app, the best starting points are usually:

- `lib/features/events/` for event behavior
- `lib/features/settings/` for sync and preferences
- `doc/` for protocol and sync semantics
