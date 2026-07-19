# ADR-0001: Unify Shell and Adaptive Workspace Layout

- Status: Accepted
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

The policy returns one immutable arrangement for a layout pass. Navigation,
reader presentation, and scene geometry must consume that same arrangement;
routes and widgets must not independently repeat the fit calculation.

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
- Medium constraints use a structural rail and may retain a list/reader split
  when content minimums fit.
- Small constraints remove structural navigation, expose one navigation toggle
  in the available top chrome or page header, and show one primary pane at a
  time.

These states are resolved from the space required by their contents, not from
one desktop/mobile breakpoint. In particular, a narrow desktop window may use
the same off-canvas navigation presentation as a phone, while retaining its
desktop window-chrome profile and mouse/keyboard input behaviour.

Fit is calculated once from the total viewport and candidate scene
requirements. It must not use a content width that has already been reduced by
the currently rendered navigation, because that creates a layout feedback
loop. The first implementation will use deterministic thresholds without
hysteresis; hysteresis may be added later only if real resize testing shows
visible boundary chatter.

Initial scene requirements reuse the product's established dimensions:

- Feed, saved, and search primary panes use `420px` as the compact comfortable
  width when deciding whether a rail remains structural.
- An embedded reader additionally requires its existing `450px` minimum plus
  the split-handle extent.
- Expanded feed navigation uses its current `260px` preferred width.
- Pinned settings navigation retains its current `720px` content requirement;
  settings may retain a rail while at least `600px` remains for its adaptive
  paper content.

These are policy inputs and named layout tokens, not platform checks. With the
current `420px` native minimum window width, the Windows `56px` rail therefore
falls back to off-canvas below approximately `477px`, so all three navigation
presentations remain reachable on desktop.

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

Search is a primary-pane variant, not a separate application shell.

Opening an article preserves the current responsive routing contract:

- When the primary list and minimum reader width fit, the article route remains
  in the feed workspace and reveals the reader pane on the right.
- When they do not fit, the article is pushed as a secondary page instead of
  squeezing a reader pane into the workspace.
- If expanded navigation is the only reason the split cannot fit, the resolved
  navigation may temporarily fall back to its rail state while preserving the
  user's expanded preference. Widening the window or closing the reader restores
  the preferred state when it fits again.

The list/search state, selection, scroll position, and reader route semantics
must survive these presentation changes.

Window resizing changes presentation, not navigation history. An article route
keeps one stable page identity while the feed workspace switches between an
embedded reader and a secondary-page presentation. A route opened narrowly by
`push` remains poppable if the window later widens; a route opened widely keeps
an explicit fallback to its list route if the window later narrows and there is
no route beneath it. Resizing must never issue `go`, `push`, `pop`, or `replace`.

### Navigation

Navigation has one preferred user state and one resolved presentation. The
preferred state records whether the user last requested expanded or collapsed
navigation. The adaptive policy resolves that preference into one of three
presentations:

- `expanded`: the stable icon rail plus the adjacent label/subscription detail
  region are inline.
- `rail`: only the stable icon rail is inline.
- `offCanvas`: no navigation width is reserved; one toggle reveals the expanded
  navigation from the leading edge.

The resolver uses content minimums in this order: preserve the preferred
expanded state when it fits, otherwise preserve a rail when rail plus primary
content fits, otherwise use off-canvas navigation. A temporary reader-driven
fallback may choose rail to retain a valid list/reader split. Automatic
fallbacks do not overwrite the user's preferred state.

Preferred navigation state is scene-local, per window, and session-scoped. The
feed and settings workspaces retain independent preferences across route
changes. This state is not persisted across application launches in this ADR.

The fixed-width icon rail owns stable horizontal anchors in both expanded and
rail presentations. Expanded navigation reveals an adjacent detail region for
labels and the subscription tree. Collapse/expand animation changes the detail
region and overall width without moving rail icons.

Opening off-canvas navigation uses one shared push-reveal interaction across
platforms: the expanded navigation enters from the leading edge while the
workspace is translated to the right. The workspace keeps its laid-out size so
opening navigation does not recalculate list/reader breakpoints or discard pane
state. The translated workspace is clipped by the viewport and may receive a
scrim according to input mode.

Only the active product scene is translated. Native window chrome, caption
buttons, and macOS traffic-light integration remain fixed to the window. On a
content-only host, the page header belongs to the scene and moves with it.
Opening navigation traps focus within the revealed pane; `Escape`, system back,
scrim activation, destination selection, or a route change closes it and
restores focus to the toggle. Reduced-motion mode performs the same state
change without translation animation.

Platform profiles may render the collapsed state differently:

- macOS may use a floating rail and capsule surfaces.
- Windows/Linux use a structural narrow rail with a divider.
- Other content-only platforms may choose a plain structural rail.

These adapters consume the same navigation data, selection state, commands,
and icon anchors. The platform profile changes the treatment of `expanded` and
`rail`; it does not prevent an extremely narrow window from resolving to
`offCanvas`.

### Windows and Linux

The title bar and left navigation share one chrome surface and form an
L-shaped background layer. There is no divider between those two regions.

The content viewport begins below the title bar and to the right of the current
left chrome width. Its top-left corner owns the transition radius. The title-bar
bottom divider begins at the content leading edge, and the navigation divider
begins below the title bar. Page titles and page actions remain in the page
header below the window title bar. Window caption buttons remain in the title
bar.

When navigation resolves to `offCanvas`, the title bar remains because it is a
window-chrome requirement. The title-bar shell-control strip provides the
navigation toggle, and no closed rail width is reserved below it.

Caption controls are never removed or compressed. The navigation toggle is the
highest-priority leading command, followed by back, search, forward, and the
update entry. The title bar reserves a draggable span before showing lower
priority commands; commands that cannot fit move to a shell overflow menu in
reverse priority order. Disabled back/forward commands may remain visible when
space permits so control positions do not jump. The current `420px` native
minimum is expected to fit the four core leading commands, the draggable span,
and all three caption buttons; the overflow rule primarily protects future
hosts and update states.

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
these observable behaviours without a separate ADR. Existing expanded and rail
states retain their current macOS treatment. The shared `offCanvas` state only
applies below the width at which a valid rail plus primary content can fit; it
must not alter the geometry of currently characterized normal-width macOS
layouts.

### Settings

Settings uses the shared window frame but remains a separate product scene. It
does not reuse the feed navigation or article workspace.

The settings scene owns:

- Settings navigation.
- Settings-local responsive navigation state.
- A search dock.
- A centered, maximum-width paper surface.

Settings uses the same `expanded`/`rail`/`offCanvas` presentation vocabulary but
has its own navigation data, layout requirements, and preferred state. Wide
settings pins the expanded navigation beside the centered paper, medium
settings may retain a structural rail, and small settings uses the shared
off-canvas push reveal plus list/detail content.

Shell control commands are supplied by the active scene. In the feed workspace,
the title-bar or leading toggle controls feed navigation. In settings, it
controls settings navigation and must not mutate the hidden feed preference.
Global history and global search remain window-level commands. Settings-local
back behaviour resolves nested detail first, then the settings list, then the
route outside settings.

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
- Adaptive workspace arrangement: the single immutable output consumed by the
  frame, active scene, navigation presentation, and reader presentation.
- Navigation presentation resolver: preferred state, content minimums,
  reader-driven fallback, and `expanded`/`rail`/`offCanvas` resolution.
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
   medium, small, touch, mouse, and keyboard environments. Introduce the
   preferred-versus-resolved navigation model without changing current
   normal-width platform geometry.
5. Make article routes presentation-stable across resizing, then express
   navigation as a stable rail plus an animated detail region without changing
   route history or selection state.
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
- Expanded, rail, and off-canvas thresholds derived from content minimums;
  widening after an automatic fallback restores the user's preferred state.
- The resolver uses total viewport constraints and returns one arrangement;
  no caller recalculates navigation or reader fit from post-layout content
  width.
- Off-canvas push reveal translates the workspace without changing its layout
  width or recalculating list/reader pane mode.
- Native title bars and caption controls remain fixed while the active scene is
  translated; dismissal, focus restoration, and reduced-motion behaviour are
  covered.
- Feed, scope, saved, later-reading, and search routes using the same workspace
  structure.
- Reader-pane appearance and reader-bottom-overlay placement.
- Settings title-bar persistence on native desktop, title-bar absence on
  content-only hosts, navigation geometry, centered paper width, and search
  dock placement.
- Feed and settings navigation preferences remain independent, and the active
  scene owns the shell toggle command.
- macOS traffic-light visible/hidden/full-screen metrics, floating controls,
  capsule rail, overlay geometry, and native bridge behaviour.
- Linux matching the Windows `titleBarExpected` profile where intended.
- Web layouts omitting native caption controls at large and narrow viewport
  widths while retaining the same feed/search/reader scene semantics.
- Tablet portrait, landscape, and multitasking widths; touch targets and safe
  areas must remain valid as the layout changes between split and single pane.
- Phone navigation, single-pane list/reader transitions, and reader-bottom
  overlays respecting system safe areas.
- Article routing retaining an embedded reader when the split fits, using a
  temporary rail fallback when that makes the split fit, and pushing a
  secondary reader page when no valid split fits.
- Resizing an open article changes only its presentation and preserves page
  identity, history depth, fallback back target, selection, and scroll state.
- Title-bar command priority and overflow at the native minimum width, including
  the update-available state.
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
