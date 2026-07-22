# Fleur

[简体中文](README.zh-CN.md) | English

[![Quality](https://github.com/ZeyrMe/Fleur/actions/workflows/quality.yml/badge.svg)](https://github.com/ZeyrMe/Fleur/actions/workflows/quality.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Fleur is a macOS-first RSS reader for following the open web with a quiet,
local-first reading workflow.

Fleur 1.0 is planned as a macOS-focused release. The source tree still contains
other platform targets, but the official 1.0 release artifacts are intended to
be macOS-only.

<!--
Product screenshot placeholder:
1. Add the final screenshot at assets/readme/fleur-macos-main.png.
2. Uncomment the block below when the image is ready.

<p align="center">
  <img src="assets/readme/fleur-macos-main.png" alt="Fleur running on macOS" width="960">
</p>
-->

## Download

Download Fleur from [GitHub Releases](https://github.com/ZeyrMe/Fleur/releases).

> macOS security note: Fleur 1.0 builds are currently unsigned and not notarized.
> On first launch, macOS Gatekeeper may show a warning. Download only from the
> official GitHub Releases page, or build from source if you prefer to audit the
> app locally.

If macOS blocks the app, open Finder, locate `Fleur.app`, Control-click it,
choose `Open`, then confirm `Open`.

If macOS says the app is damaged or cannot be opened, see the Q&A section below.

## What Fleur Does

- Read RSS and Atom feeds in a desktop workspace designed around article lists
  and a focused reader pane.
- Discover feeds from websites, add direct RSS/Atom URLs, and organize
  subscriptions with folders, tags, starred articles, unread filters, and read
  later.
- Import and export OPML so your subscriptions stay portable.
- Extract full article content, cache images and web pages for offline reading,
  and refresh sources in the background.
- Sync with local accounts, Miniflux, Fever, and Google Reader compatible
  services.
- Tune the reader with font stacks, reading width, line height, reading texture,
  code typography, syntax highlighting, math rendering, in-reader search, and
  keyboard shortcuts.
- Configure translation and AI summary services for optional reading assistance.

## Platform Policy

| Platform | 1.0 release status | Notes |
| --- | --- | --- |
| macOS 10.15+ | Official 1.0 target | Distributed as an unsigned, unnotarized DMG. |
| Windows | Not included in 1.0 artifacts | 0.x releases may have Windows builds; 1.0 is macOS-first. |
| Linux | Not included in 1.0 artifacts | Source paths may exist, but no official 1.0 package is planned. |
| Android / iOS | Experimental source targets | Useful for local development only unless stated otherwise. |
| Web | Not supported | Not part of the supported release path. |

## Localization

Fleur uses Flutter localization files for the app UI and macOS menu strings.

| Status | Languages |
| --- | --- |
| Primary | English, Simplified Chinese, Traditional Chinese |
| Beta / experimental | German, Spanish, French, Japanese, Korean, Portuguese, Portuguese (Brazil) |

Beta localization means the strings are present, but native-speaker review,
layout checks, terminology cleanup, notification wording, and release-note
wording still need review. Reports and pull requests for localization polish are
very welcome.

## Build From Source

Recommended toolchain:

- Flutter 3.38.x stable, matching the current CI setup
- Dart 3.10.x
- Xcode for macOS builds

Install dependencies:

```bash
flutter pub get
```

Generate Isar model code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run Fleur on macOS:

```bash
flutter run -d macos
```

Build a macOS release locally:

```bash
flutter build macos --release
```

## Quality Checks

```bash
./tool/quality/format_dart.sh
./tool/quality/check_generated_sources.sh
flutter analyze
flutter test
```

Integration tests may require an explicit device:

```bash
flutter test -d macos integration_test/category_query_benchmark_test.dart
```

## Project Structure

Fleur follows a Clean Architecture-style Flutter structure with Riverpod for
state management.

```text
lib/
├── app/          # App entry, routing, runtime host
├── features/     # Product features and their local layers
├── models/       # Isar models
├── repositories/ # Data access
├── providers/    # Riverpod providers and controllers
├── services/     # RSS, sync, extraction, settings, AI, notifications
├── ui/           # App shell, shared scenes, and design system
├── widgets/      # Existing shared UI components, migrated incrementally
├── theme/        # Theme and design tokens
├── l10n/         # Localization files
├── utils/        # Utilities
└── db/           # Database setup
```

New product code belongs in `lib/features/<feature>/`, with `domain`, `data`,
`application`, and `presentation` layers only where they clarify ownership.
Each feature exposes a small `<feature>.dart` facade. Keep application
composition in `app/`, shared shell and scene UI in `ui/`, and visual primitives
in `ui/design_system/`. The remaining top-level shared folders are migrated by
feature over time; do not add new `screens/` or generic `widgets/` entries.

## Tech Stack

| Area | Technology |
| --- | --- |
| App framework | [Flutter](https://flutter.dev/) |
| State management | [Riverpod](https://riverpod.dev/) |
| Local database | [Isar Community](https://pub.dev/packages/isar_community) |
| Routing | [go_router](https://pub.dev/packages/go_router) |
| HTTP | [Dio](https://pub.dev/packages/dio) |
| RSS parsing | [rss_dart](https://pub.dev/packages/rss_dart) |
| HTML rendering | [flutter_widget_from_html](https://pub.dev/packages/flutter_widget_from_html) |
| Desktop windowing | [window_manager](https://pub.dev/packages/window_manager) |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |

## Q&A

### Why is Fleur 1.0 macOS-only?

Fleur 1.0 focuses on making the desktop reading experience feel native on
macOS: window chrome, keyboard navigation, split workspaces, reader layout, and
menu behavior. Releasing 1.0 as macOS-first keeps the support promise honest.

### Why is the macOS app unsigned and not notarized?

Fleur is an independently maintained open-source project. The 1.0 macOS build is
distributed without Apple code signing or notarization because the project does
not currently maintain a paid Apple Developer Program membership. Apple
currently lists that program at [USD 99/year](https://developer.apple.com/programs/).

This means macOS may warn you the first time you open the app. It does not mean
the app is intentionally unsafe, but unsigned builds also do not provide Apple's
developer identity verification. Download Fleur only from the official GitHub
Releases page, or build it from source if you prefer.

### What if macOS says Fleur is damaged or cannot be opened?

This can happen when Gatekeeper keeps a downloaded, unsigned app in quarantine.
Only continue if you downloaded Fleur from the official GitHub Releases page or
built it yourself from source.

Try these options in order:

1. Copy `Fleur.app` to `/Applications`.
2. Open Finder, locate `Fleur.app`, Control-click it, choose `Open`, then confirm
   `Open`.
3. Open System Settings -> Privacy & Security, scroll to the Security section,
   and choose `Open Anyway` for Fleur if macOS shows that option.
4. If macOS still reports that the app is damaged, remove the quarantine
   attribute:

```bash
xattr -dr com.apple.quarantine /Applications/Fleur.app
```

Then open `Fleur.app` again from Finder.

This does not sign or notarize the app; it only removes the local quarantine flag
from your copy. Avoid disabling Gatekeeper globally.

### Are Windows and Linux discontinued?

Not necessarily. The 1.0 release policy is about official artifacts and
validation focus, not a permanent removal of source code paths. Windows and
Linux support can be revisited when there is enough validation and release
maintenance time.

### Which languages does Fleur support?

English, Simplified Chinese, and Traditional Chinese are the primary supported
languages. German, Spanish, French, Japanese, Korean, Portuguese, and Portuguese
(Brazil) are included as Beta / experimental localizations in 1.0.

### What does Beta localization mean?

It means the locale is available in the app, but it has not yet completed the
same level of language review as English and Chinese. Please report awkward
wording, truncated labels, menu issues, untranslated strings, or release-note
mistakes.

## Contributing

Bug reports, localization review, and focused pull requests are welcome. For
localization issues, please include:

- Locale and app version
- Screenshot when layout or truncation is involved
- Current wording
- Suggested wording and a short reason

## License

Fleur is released under the [MIT License](LICENSE).
