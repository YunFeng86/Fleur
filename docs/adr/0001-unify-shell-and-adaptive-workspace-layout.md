# ADR-0001: Unify Shell and Adaptive Workspace Layout

- Status: Proposed
- Date: 2026-07-19
- Decision owners: Fleur maintainers

## Context

Fleur's UI has two stable product scenes:

- The feed workspace, composed of navigation, a primary list pane, an optional
  reader pane, and reader-local overlays.
- The settings workspace, composed of settings navigation and a centered
  paper-like content surface with a search dock.

These scenes run in several environments: native desktop windows, browser
viewports, tablets, phones, and potentially embedded or full-screen surfaces.
Operating system, available size, and input method are independent facts. A
large Web viewport may use a desktop-like workspace without native window
chrome, while an iPad may move between split and single-pane layouts as it
rotates or enters multitasking.

Both scenes sit inside the application shell. Native desktop hosts may add
platform window chrome around the scene: macOS integrates shell controls with
the traffic-light region and uses floating/capsule treatments when navigation
is collapsed, while Windows and Linux use a persistent custom title bar whose
title bar and left navigation form one connected L-shaped chrome region behind
the content. Web, tablet, phone, and embedded hosts use content-only chrome.

The current implementation has grown incrementally from the macOS layout.
Window chrome, navigation geometry, shell controls, content surface treatment,
and route-specific composition are spread across `AppShell`, `SettingsScreen`,
`Sidebar`, router wrappers, and workspace-layer widgets. Several of these files
now exceed 1000 lines:

- `lib/ui/app_shell.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/sidebar.dart`

This makes a small visual change require edits at several call sites. It also
allows platform checks and geometry calculations to leak past the platform
seam. The existing `ShellChromeLayout` is the beginning of the right model, but
it is not yet the single source of truth for shell composition.

## Decision

Fleur will incrementally converge on one shared shell and workspace structure
driven by two orthogonal policies:

- Window chrome policy, resolved from host capabilities and platform
  conventions.
- Adaptive workspace policy, resolved from content constraints, safe areas,
  and input method.

We will not create separate Windows, Linux, macOS, Web, tablet, or phone
implementations of the product scenes.

The shared structure has three levels:

1. A window-frame module owns platform chrome, the left chrome region, the
   content viewport, divider geometry, drag regions, and the `ShellLayerScope`
   interface exposed to scene content.
2. A scene host selects the feed workspace or settings workspace without
   recreating platform window chrome.
3. Each workspace owns its product-specific panes and local interaction state.

`ShellChromeLayout.resolve()` or its direct successor remains the window-chrome
policy source of truth. The resolved profile, rather than scattered platform
checks, determines:

- Whether a dedicated title bar exists.
- Where shell controls are placed.
- Whether collapsed navigation is structural or floating.
- The navigation surface treatment.
- The content surface radius, shadow, and leading-edge treatment.
- Window-caption insets and title-bar divider geometry.

A separate adaptive workspace policy determines:

- Whether navigation is inline, a structural rail, or off-canvas.
- Whether primary and reader panes are split or shown one at a time.
- Whether settings navigation is pinned or list/detail.
- Touch target sizing, hover availability, and keyboard focus behaviour.
- Safe-area treatment for headers and reader-local overlays.

Native behaviour remains behind platform adapters: the macOS window chrome
bridge owns traffic-light and zoom/drag integration, while `window_manager`
owns Windows/Linux window dragging and caption commands.

## Layout Model

### Adaptive environment model

Window chrome and workspace layout must not be inferred from one platform enum.
The shell resolves them independently.

Window chrome has three semantic profiles:

- `integratedCorner`: a native desktop window has mandatory leading system
  elements, as on macOS with traffic lights.
- `titleBarExpected`: a native desktop window conventionally requires a
  persistent custom title bar and caption controls, as on Windows and the
  supported Linux desktop configuration.
- `contentOnly`: the host owns window chrome or has no window chrome, as on
  Web, iPad, phones, and embedded surfaces.

Workspace adaptation is content-driven:

- Large constraints may show expanded navigation, a primary list, and a reader
  pane simultaneously.
- Medium constraints use a structural rail or temporary navigation and may
  retain a list/reader split when content minimums fit.
- Small constraints use off-canvas or compact navigation and show one primary
  pane at a time.

Input adaptation is independent of width. Touch layouts provide at least 44px
interactive targets and safe gesture spacing. Mouse layouts retain hover and
precise compact controls. Keyboard-capable environments retain visible focus
and logical traversal regardless of pointer type.

Default environment mapping is:

- Native macOS window: `integratedCorner` plus constraint-driven workspace.
- Native Windows/Linux window: `titleBarExpected` plus constraint-driven
  workspace.
- Browser: `contentOnly`; the browser or PWA host owns caption controls.
- iPad/tablet: `contentOnly`; portrait, landscape, and multitasking widths are
  resolved from constraints rather than device name.
- Phone: `contentOnly` with small-workspace defaults and single-pane content.
- Other embedded/external surfaces: `contentOnly` unless the host explicitly
  advertises a native window-chrome capability.

Full-screen is a state of the current host, not a fourth profile. For example,
macOS full-screen continues to use integrated metrics with hidden traffic
lights rather than becoming a phone/content-only layout.

### Feed workspace

The feed workspace remains one stable scene across all feeds, scopes, saved
items, later-reading items, and search:

- Navigation pane.
- Page header containing the current scope title and page actions.
- Primary pane containing an article list or search results.
- Optional reader pane.
- Reader-local bottom overlay.

Search is a primary-pane variant, not a separate application shell. Opening an
article changes the pane arrangement; it does not replace the workspace.

### Navigation

Expanded and collapsed navigation are presentation states of one navigation
module. A fixed-width icon rail owns the stable horizontal anchors. Expanded
navigation reveals an adjacent detail region for labels and the subscription
tree. Collapse/expand animation changes the detail region and the overall
width without moving the rail icons.

Platform profiles may render the collapsed state differently:

- macOS may use a floating rail and capsule surfaces.
- Windows/Linux use a structural narrow rail with a divider.
- Other content-only platforms may choose a plain structural rail.

These adapters consume the same navigation data, selection state, commands,
and icon anchors.

### Windows and Linux

The title bar and left navigation share one chrome surface and form an
L-shaped background layer. There is no divider between those two regions.

The content viewport begins below the title bar and to the right of the current
left chrome width. Its top-left corner owns the transition radius. The title-bar
bottom divider begins at the content leading edge, and the navigation divider
begins below the title bar. Page titles and page actions remain in the page
header below the window title bar. Window caption buttons remain in the title
bar.

### macOS

The current macOS behaviour is a compatibility constraint, not a migration
target. The refactor must preserve:

- Traffic-light avoidance and native metric updates.
- Current expanded shell-control placement.
- Floating controls and capsule navigation when collapsed.
- Rail overlay behaviour and content leading insets.
- Full-screen fallback and click-safe top insets.
- Existing macOS native bridge semantics.

The shared frame may reorganize the implementation, but it must not change
these observable behaviours without a separate ADR.

### Settings

Settings uses the shared window frame but remains a separate product scene. It
does not reuse the feed navigation or article workspace.

The settings scene owns:

- Settings navigation.
- Settings-local responsive navigation state.
- A search dock.
- A centered, maximum-width paper surface.

On Windows/Linux, settings navigation participates in the same connected
title-bar/left-chrome treatment. On macOS, settings continues to respect the
integrated traffic-light layout.

On wide Web and tablet layouts, the paper remains centered at its maximum
reading width while settings navigation may be pinned. On narrow tablet and
phone layouts, settings uses list/detail navigation and the paper becomes a
full-width content surface with safe-area-aware padding.

## Module Responsibilities

The refactor will favour deep modules with small interfaces and strong
locality. Exact Dart type names may be chosen during implementation, but the
responsibilities are fixed by this ADR:

- Window frame: chrome composition and top-level geometry.
- Window chrome profile: semantic host-chrome decisions only.
- Adaptive workspace policy: constraint, safe-area, and input decisions only.
- Shell control strip: one ordered control model and its presentation.
- Navigation pane: rail anchors, expanded detail region, and transition.
- Feed workspace: list/reader pane composition.
- Settings workspace: settings navigation, search dock, and paper placement.
- Workspace surfaces: radius, shadow, clipping, and edge rendering.

The window frame must not fetch article, feed, or settings data. Product scenes
must not create native caption controls or calculate platform window geometry.

## File Size and Locality

Line count is a design signal, not the sole reason to split a module. However,
files over 1000 lines require an explicit responsibility review and must not
continue growing during this migration.

New and extracted files should normally stay well below 1000 lines. Extraction
must follow a coherent responsibility and pass the deletion test: deleting the
module should cause its hidden complexity to reappear across callers. We will
not create pass-through files merely to satisfy a line-count target.

During this migration:

- `app_shell.dart`, `settings_screen.dart`, and `sidebar.dart` must shrink or
  remain neutral in each related change; they may not accumulate new shell
  responsibilities.
- Private widgets may move to focused files when they share one responsibility
  and can be tested through a clear interface.
- Platform conditions should move toward the profile resolver or native
  adapters rather than being copied into extracted files.
- Breakpoint and input decisions should move toward the adaptive workspace
  policy rather than being repeated by individual scenes.

## Incremental Migration

This is a local refactor, not a big-bang rewrite. Each stage must preserve a
green test suite and observable platform behaviour.

1. Add characterization tests for shell geometry, control ordering, navigation
   anchors, scene persistence, and macOS chrome metrics.
2. Consolidate the duplicated shell control model and control-strip rendering.
3. Extract the shared window-frame geometry and chrome composition from
   `AppShell` while keeping the existing feed workspace intact.
4. Extract adaptive workspace decisions from route widgets and verify large,
   medium, small, touch, mouse, and keyboard environments.
5. Express navigation as a stable rail plus an animated detail region without
   changing routes or selection state.
6. Move the settings scene under the shared window frame and remove its
   duplicate title-bar composition.
7. Remove obsolete platform conditionals and route-level surface decisions
   after all callers consume the shared interfaces.
8. Split remaining oversized files by the responsibilities defined above.

No stage may combine shell refactoring with unrelated business logic, storage,
sync, or navigation-history changes.

## Verification Gates

Every migration stage must retain or add focused tests for:

- Windows/Linux title-bar height, caption hit regions, connected rail geometry,
  content offsets, transition radius, and divider start points.
- Stable rail icon positions before, during, and after expand/collapse.
- Feed, scope, saved, later-reading, and search routes using the same workspace
  structure.
- Reader-pane appearance and reader-bottom-overlay placement.
- Settings title-bar persistence on native desktop, title-bar absence on
  content-only hosts, navigation geometry, centered paper width, and search
  dock placement.
- macOS traffic-light visible/hidden/full-screen metrics, floating controls,
  capsule rail, overlay geometry, and native bridge behaviour.
- Linux matching the Windows `titleBarExpected` profile where intended.
- Web layouts omitting native caption controls at large and narrow viewport
  widths while retaining the same feed/search/reader scene semantics.
- Tablet portrait, landscape, and multitasking widths; touch targets and safe
  areas must remain valid as the layout changes between split and single pane.
- Phone navigation, single-pane list/reader transitions, and reader-bottom
  overlays respecting system safe areas.
- Keyboard traversal and focus visibility on desktop-class Web and tablet
  environments with hardware keyboards.

Static analysis and the relevant widget/smoke tests must pass after every
stage. Visual verification on Windows, macOS, large/narrow Web, tablet
portrait/landscape, and phone constraints is required before removing an old
implementation path.

## Consequences

Positive consequences:

- Platform differences remain explicit without duplicating product scenes.
- Chrome geometry and visual treatment gain locality.
- Search and reader transitions operate within a stable workspace.
- Settings gains persistent window chrome without owning it.
- Future shell changes have a smaller interface and test surface.
- Oversized files can shrink along meaningful responsibilities.

Costs and risks:

- The migration temporarily retains old and new composition paths.
- Animation regressions are possible if rail anchors or pane identity change.
- macOS regressions may be subtle and require characterization tests before
  extraction.
- A shared frame can become shallow if it exposes every geometry detail; its
  interface must remain semantic rather than mirroring its implementation.

## Alternatives Considered

### Keep patching the current `AppShell`

Rejected. It would preserve the current leakage of chrome, scene, navigation,
and product responsibilities and allow oversized files to continue growing.

### Build separate platform shells

Rejected. Native desktop, Web, tablet, and phone environments differ in chrome,
constraints, and input presentation, not in feed, navigation, search, reader,
or settings semantics. Separate shells would duplicate product behaviour and
tests.

### Resolve the entire layout from operating system

Rejected. Operating system does not describe browser ownership of chrome,
tablet multitasking width, window resizing, pointer type, safe areas, or
full-screen state. Host capabilities and content constraints must remain
independent inputs.

### Force settings into the feed workspace

Rejected. Settings has different information density, responsive navigation,
and paper-layout requirements. It shares the window frame, not the feed scene.

### Split files immediately by line count

Rejected. Mechanical splitting would create shallow pass-through modules and
reduce locality without clarifying ownership.
