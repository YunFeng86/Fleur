# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Build for specific platforms
flutter build windows
flutter build macos
flutter build linux
flutter build apk
flutter build ios

# Generate Isar model code (required after modifying models/*.dart)
dart run build_runner build

# Clean and regenerate (if code generation has issues)
dart run build_runner build --delete-conflicting-outputs

# Code quality and formatting
flutter analyze              # Run static analysis
dart format .                # Format code (non-configurable, follows Dart style guide)
dart fix --dry-run           # Preview auto-fixable issues
dart fix --apply             # Auto-fix issues (async patterns, bool literals, etc.)

# Run tests
flutter test

# Quality check scripts (from README)
./tool/quality/format_dart.sh              # Format check (excludes generated files)
./tool/quality/check_generated_sources.sh # Generated code sync check
```

## Current Boundary Contract

- macOS 10.15+ is the official Fleur 1.0 release target.
- Windows and Linux retain maintained desktop source targets, including their
  custom title bar and connected navigation chrome, but are not official 1.0
  release artifacts.
- Android and iOS are experimental source targets for local validation.
- Web is currently unsupported in this repository; `flutter build web` is expected to fail until the current web-target blockers are resolved.

## Architecture Overview

This is a **Flutter RSS reader** built with **Clean Architecture** and **Riverpod** state management.

### Layer Structure

```
lib/
├── app/          # Entry point, routing configuration (go_router)
├── models/       # Isar data models (@collection)
├── repositories/ # Data access layer (CRUD operations)
├── providers/    # Riverpod state management
├── services/     # Business logic (RSS parsing, article extraction)
├── screens/      # UI screens (Home, Reader, Settings, Saved, Search)
├── widgets/      # Reusable UI components
├── ui/           # Global nav, layout, dialogs, actions
├── theme/        # Material theme configuration
├── l10n/         # Internationalization (en, zh, zh_Hant)
├── utils/        # Utility functions
└── db/           # Isar database initialization
```

### Core Technologies

- **State Management**: Riverpod with Stream-based reactive providers
- **Database**: Isar NoSQL (auto-increment IDs, indexed queries, watchers)
- **Routing**: go_router with responsive navigation (900px breakpoint for global nav rail/bottom)
- **HTTP**: dio for network requests
- **RSS Parsing**: rss_dart (supports both RSS and Atom)
- **HTML Rendering**: flutter_widget_from_html
- **Window Management**: window_manager (desktop)
- **Notifications**: flutter_local_notifications
- **Background Sync**: workmanager (platform-specific background tasks)

### Data Model Architecture

**Isar Collections**:
- `Feed`: RSS subscriptions (url, title, categoryId, lastSyncedAt, etag, lastError)
- `Article`: Articles (feedId, categoryId, content, extractedContentHtml, isRead, isSaved)
- `Category`: User-defined categories
- `Tag`: Article tags with hex colors

**Key Design Patterns**:
1. **Denormalized category filter (under review)**: `categoryId` is duplicated in Articles for fast category filtering (see [feed_repository.dart](lib/repositories/feed_repository.dart)). Keep benchmark interpretation consistent before treating this optimization as permanently justified.
2. **Dual Content Storage**: Articles store both RSS `contentHtml` and extracted `extractedContentHtml`
3. **Stream-based Queries**: Repositories return `Stream<List<T>>` for reactive UI updates
4. **Sync State**: Feeds track sync status (lastCheckedAt, lastStatusCode, lastDurationMs, lastError)

### Riverpod Provider Hierarchy

```
isarProvider (overridden in main.dart)
  ├─ feedRepositoryProvider
  ├─ articleRepositoryProvider
  └─ categoryRepositoryProvider
       └─ feedsProvider (StreamProvider)
            └─ articlesProvider (StreamProvider.family)
                 └─ articleListControllerProvider (StateNotifierProvider)
```

**Important**: `isarProvider` throws `UnimplementedError` by default and must be overridden in `main()` after database initialization ([core_providers.dart](lib/providers/core_providers.dart)).

### Routing Behavior

- `/all`, `/starred`, `/read-later` - top-level article scopes
- `/feed/:feedId`, `/category/:categoryId`, `/tag/:tagId` - scoped article lists
- Each article scope has a nested `/article/:articleId` route
- `/search` and `/search/article/:id` - search list and responsive reader
- `/add-subscription` - subscription task page
- `/settings` - settings scene inside the shared application shell

**Responsive workspace**:
- `AdaptiveWorkspaceArrangement.resolve()` is the single source of truth for
  `expanded`, `rail`, and `offCanvas` navigation plus embedded/secondary reader
  presentation.
- Route history remains stable while resizing changes reader presentation.
- Feed and settings navigation preferences are independent.
- macOS uses integrated traffic-light chrome and a floating capsule rail;
  Windows/Linux use a persistent custom title bar with connected left chrome.
- See `docs/adr/0001-unify-shell-and-adaptive-workspace-layout.md` before
  changing shell, navigation, settings, or reader geometry.

### Code Generation (Isar)

All models in `models/` use `@collection` annotation and require code generation:

1. Add model with `part 'model.g.dart'` and `@collection` class
2. Run `dart run build_runner build`
3. Generated code provides Isar collection accessors (e.g., `_isar.feeds`, `_isar.articles`)

### Adding New Features

**New Model**:
1. Create in `models/` with `@collection` annotation and `part 'model.g.dart'`
2. Run `dart run build_runner build`
3. Create repository in `repositories/`
4. Add repository provider in `providers/` (if needed)

**New Screen**:
1. Add screen widget in `screens/`
2. Register route in `app/router.dart` with proper page transitions
3. Add to `GlobalNavDestination` enum if it's a top-level destination
4. Add localization strings in `l10n/app_*.arb`

**New Provider**:
- Use `StreamProvider` for Isar query watchers
- Use `StateNotifierProvider` for complex state with mutations
- Use `Provider` for simple read-only values
- Remember: `isarProvider` must be overridden in `main()` after DB initialization

**Layout Decisions**:
- Resolve host chrome through `ShellChromeLayout.resolve()`.
- Consume the active `AdaptiveWorkspaceArrangement` from `ShellLayerScope`
  instead of repeating width checks inside screens or routes.
- Respect `kMinReadingWidth` (450px) when changing reader pane composition.
- Keep platform-specific window operations behind the macOS bridge or
  `window_manager`; product scenes must not create native caption controls.

### Services

**RSS & Content**:
- `FeedParser`: Parses RSS/Atom feeds with automatic format detection
- `ArticleExtractor`: Extracts full article content with CMS-specific heuristics (WordPress, Hexo, Hugo, Halo)
- `ArticleCacheService`: Caches article content with flutter_cache_manager
- `FaviconService`: Fetches and caches feed favicons
- `OPMLService`: Import/export subscriptions via OPML

**Sync & Accounts**:
- `SyncService`: Base sync service with batch refresh, exponential backoff retry
- `FeverSyncService`: Fever API sync client
- `MinifluxSyncService`: Miniflux API sync client
- `AccountStore`: Multi-account management with secure credential storage

**Translation**:
- `TranslationService`: AI-powered article translation
- `AIServiceClient`: Generic AI service client for translation

**Notifications**:
- `NotificationService`: New article push notifications
- `BackgroundSyncService`: Periodic sync via workmanager

**Search**:
- `ReaderSearchService`: Full-text article search

### Internationalization

Primary languages are English (`en`), Simplified Chinese (`zh`), and
Traditional Chinese (`zh_Hant`). German, Spanish, French, Japanese, Korean,
Portuguese, and Brazilian Portuguese are present as beta/experimental locales.

Add localization keys to all ARB files in `l10n/` and run `flutter pub get` to regenerate `app_localizations.dart`.

### Dependencies Injection Pattern

Override providers in tests using `ProviderScope(overrides: [...])`. Example in [main.dart](lib/main.dart).

### Code Quality Standards

**Static Analysis**: [analysis_options.yaml](analysis_options.yaml) enforces strict rules to prevent bugs:

**Async Safety**:
- `unawaited_futures` / `discarded_futures` - All `Future` calls must be awaited or marked with `unawaited()`
- `avoid_void_async` - Prevents accidental async void functions
- `cancel_subscriptions` / `close_sinks` - Stream subscriptions/sinks must be closed

**Type Safety**:
- `implicit-casts: false` / `implicit-dynamic: false` - Strict mode, no implicit type conversions
- `avoid_dynamic_calls` - No calls on `dynamic` types
- `no_adjacent_strings_in_list` - Catches accidental list concatenation bugs

**Logic Errors**:
- `use_build_context_synchronously` - Catches async/UI timing bugs
- `no_logic_in_create_state` - Prevents logic in `createState`
- `use_key_in_widget_constructors` - Widgets should have keys

**Exclusions**: Generated files (`*.g.dart`, `*.freezed.dart`) are excluded from analysis.

**Auto-fixing**: Run `dart fix --apply` to automatically resolve most issues before committing.
