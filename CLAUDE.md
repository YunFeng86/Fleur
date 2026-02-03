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
flutter analyze              # Run static analysis (53 rules from analysis_options.yaml)
dart format .                # Format code (non-configurable, follows Dart style guide)
dart fix --dry-run           # Preview auto-fixable issues
dart fix --apply             # Auto-fix issues (async patterns, bool literals, etc.)

# Run tests
flutter test
```

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
├── screens/      # UI screens (Home, Reader, Settings)
├── widgets/      # Reusable UI components
├── theme/        # Material theme configuration
├── l10n/         # Internationalization (en, zh, zh_Hant)
├── utils/        # Utility functions
└── db/           # Isar database initialization
```

### Core Technologies

- **State Management**: Riverpod with Stream-based reactive providers
- **Database**: Isar NoSQL (auto-increment IDs, indexed queries, watchers)
- **Routing**: go_router with responsive navigation (900px breakpoint)
- **HTTP**: dio for network requests
- **RSS Parsing**: rss_dart (supports both RSS and Atom)
- **HTML Rendering**: flutter_widget_from_html

### Data Model Architecture

**Isar Collections**:
- `Feed`: RSS subscriptions (url, title, categoryId, lastSyncedAt)
- `Article`: Articles (feedId, categoryId, content, fullContent, isRead)
- `Category`: User-defined categories

**Key Design Patterns**:
1. **Denormalization**: `categoryId` duplicated in Articles for fast filtering (see [feed_repository.dart:48-56](lib/repositories/feed_repository.dart#L48-L56))
2. **Dual Content Storage**: Articles store both RSS `content` and extracted `fullContent`
3. **Stream-based Queries**: Repositories return `Stream<List<T>>` for reactive UI updates

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

**Important**: `isarProvider` throws `UnimplementedError` by default and must be overridden in `main()` after database initialization ([core_providers.dart:5-7](lib/providers/core_providers.dart#L5-L7)).

### Routing Behavior

- `/` - Home screen with 3-pane layout (sidebar | feed list | article reader)
- `/article/:id` - Article reader (responsive: shows in right pane on desktop ≥900px, full screen on mobile)
- `/settings` - Settings screen

### Code Generation (Isar)

All models in `models/` use `@collection` annotation and require code generation:

1. Add model with `part 'model.g.dart'` and `@collection` class
2. Run `dart run build_runner build`
3. Generated code provides Isar collection accessors (e.g., `_isar.feeds`, `_isar.articles`)

### Adding New Features

**New Model**:
1. Create in `models/` with `@collection` annotation
2. Run `dart run build_runner build`
3. Create repository in `repositories/`
4. Add repository provider in `providers/` (if needed)

**New Screen**:
1. Add screen widget in `screens/`
2. Register route in `app/router.dart`
3. Add localization strings in `l10n/app_*.arb`

**New Provider**:
- Use `StreamProvider` for Isar query watchers
- Use `StateNotifierProvider` for complex state with mutations
- Use `Provider` for simple read-only values

### Services

- `FeedParser`: Parses RSS/Atom feeds with automatic format detection
- `ArticleExtractor`: Extracts full article content with CMS-specific heuristics (WordPress, Hexo, Hugo, Halo)
- `ArticleCacheService`: Caches article content with flutter_cache_manager

### Internationalization

Supported languages: English (`en`), Simplified Chinese (`zh`), Traditional Chinese (`zh_Hant`).

Add localization keys to all ARB files in `l10n/` and run `flutter pub get` to regenerate `app_localizations.dart`.

### Dependencies Injection Pattern

Override providers in tests using `ProviderScope(overrides: [...])`. Example in [main.dart:12-16](lib/main.dart#L12-L16).

### Code Quality Standards

**Static Analysis**: [analysis_options.yaml](analysis_options.yaml) enforces strict rules to prevent bugs:
- **Async Safety**: All `Future`-returning calls must be awaited or explicitly marked with `unawaited()`
- **Type Safety**: No implicit casts or dynamic calls (strict mode enabled)
- **Resource Management**: Stream subscriptions and sinks must be closed
- **Logic Errors**: BuildContext usage in async callbacks is flagged

**Critical Rules**:
- `unawaited_futures` / `discarded_futures` - Prevents silent error swallowing
- `use_build_context_synchronously` - Catches async/UI timing bugs
- `implicit-casts: false` - Type errors caught at analysis time, not runtime

**Auto-fixing**: Run `dart fix --apply` to automatically resolve most issues before committing.
