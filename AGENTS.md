# Repository Guidelines

## Project Structure & Module Organization
Source code lives under `lib/` and follows Clean Architecture with Riverpod. Key modules include `app/`, `models/`, `repositories/`, `providers/`, `services/`, `screens/`, `widgets/`, `theme/`, `l10n/`, `utils/`, and `db/`. Assets (icons, images) are in `assets/`. Tests live in `test/` (unit/widget) and `integration_test/` (integration). Platform-specific folders (`android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`) contain build targets. Design notes and migration docs are in `docs/`.

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies.
- `dart run build_runner build` — generate Isar model code after changing `models/`.
- `dart run build_runner build --delete-conflicting-outputs` — regenerate on codegen conflicts.
- `flutter run` / `flutter run -d windows` — run the app locally (choose device).
- `flutter build windows` (or `apk`, `ios`, `macos`, `linux`) — produce release builds.
- `flutter analyze` — run static analysis (uses `flutter_lints`).
- `flutter test` / `flutter test integration_test` — run unit and integration tests.

## Coding Style & Naming Conventions
Use standard Dart/Flutter formatting with 2-space indentation (see `lib/main.dart`). File names are `lower_snake_case` (for example, `feed_parser.dart`). Types use `UpperCamelCase`, and variables/functions use `lowerCamelCase`. Lints are defined in `analysis_options.yaml` (via `flutter_lints`).

## Testing Guidelines
Tests use `flutter_test` and `integration_test` (see `pubspec.yaml`). Name test files with the `_test.dart` suffix and place them in `test/` or `integration_test/`. Add tests for new logic and regressions, then run `flutter test` (and `flutter test integration_test` when applicable).

## Commit & Pull Request Guidelines
Commit history follows Conventional Commit-style prefixes, primarily `feat:` and `fix:` (for example, `feat: 添加对 article 标签的支持`). Keep messages short and scoped to one change. For PRs, include a clear summary, linked issues when relevant, test results, and screenshots for UI changes.

## Configuration & Localization
Localization lives in `l10n/` with config in `l10n.yaml`. When adding strings, update all ARB files and run `flutter pub get` to regenerate localization output.
