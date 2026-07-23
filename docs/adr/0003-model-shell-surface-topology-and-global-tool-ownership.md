# ADR-0003: Model Shell Surface Topology and Global Tool Ownership

- Status: Accepted
- Date: 2026-07-23
- Decision owners: Fleur maintainers

## Context

ADR-0001 established a shared window frame, platform chrome profiles, and
adaptive workspace arrangements. It also characterized the existing desktop
treatments: Windows and Linux use a connected title-bar and navigation chrome,
while macOS integrates traffic lights and may use floating capsule treatments
when navigation is collapsed.

That decision did not explicitly separate two different concepts:

- The visual material surfaces that form the shell and product workspace.
- The ownership of global commands, focus, hit testing, and native-window
  reservations.

As a result, a global command can currently change visual and widget ownership
as navigation changes. For example, a command may live in expanded navigation
and then reappear as a floating control when navigation is collapsed. This
makes geometry, focus continuity, animation, accessibility semantics, and
scene transitions harder to reason about.

The distinction is especially visible on native desktop hosts. A collapsed
macOS workspace is not a conventional structural sidebar: the shell's material
surface separates into a top tool island and a leading navigation island over a
full scene canvas. A collapsed Windows workspace instead retains a title-bar
fragment and a narrow leading rail fragment that form one connected frame.
The global controls may appear visually above the workspace in both cases, but
they must not create a fourth, unrelated background surface.

The current shell already has useful foundations: `ShellChromeLayout`,
`ShellFrameGeometry`, `ShellWindowFrame`, and `ShellControlStrip`. Settings is
also inside the shared frame. However, settings still calculates part of its
own scene geometry, and some global controls are currently rendered by local
navigation or scene headers.

## Decision

This ADR supplements ADR-0001. It preserves the shared window-frame,
platform-profile, and adaptive-workspace decisions made there, while refining
desktop shell topology and global-tool ownership.

### Surface model

The shell has three persistent visual material surfaces:

1. `L1 / ShellCanvas` is the shell material surface. It always paints the full
   viewport, even where a higher surface normally hides it. This is a rendering
   invariant that prevents exposed transparent gaps during resize, collapse,
   and scene-transition frames; it does not require L1 to remain visibly
   exposed everywhere.
2. `L2 / SceneCanvas` is the active product scene's working canvas, such as
   the feed list, search workspace, or settings workspace.
3. `L3 / DetailSurface` is a context-specific raised surface, such as an
   article reader, settings paper, or secondary detail.

`L4 / Global Tool Plane` is a separate logical ownership plane for global
commands, focus, hit testing, and platform-control reservations. It is not a
fourth material surface, a fourth palette token, or a full-screen transparent
overlay. Its background, radius, shadow, and island treatment inherit from
the relevant L1 fragment.

Menus, dialogs, command palettes, tooltips, and other transient UI remain
above these planes in the normal overlay system. They are not part of L4.

### Global tool ownership

The shell owns one `ShellGlobalToolArea`. It owns the stable identity of global
actions such as navigation toggle, history navigation, global search entry,
and update entry. Active scenes supply command availability and callbacks, but
the feed workspace, settings workspace, reader, and sidebar must not each
create another copy of the same global control.

The global tool area may change presentation with the shell topology without
changing ownership. An integrated appearance and an island appearance are
different presentations of one shell-owned control area, not a reparenting of
commands between the sidebar and the frame.

Native window controls are system-reserved slots of the global tool plane:

- macOS traffic lights retain native ownership and hit testing. Flutter uses
  native metrics to reserve their safe region and must not cover it with an
  opaque hit target.
- Windows and supported Linux caption controls retain their existing reserved
  title-bar region and drag behavior. Application controls must not consume
  caption space or the minimum drag region.

### L1 topology

L1 may be visually continuous or visually fragmented. The resolved platform
chrome profile and adaptive navigation presentation determine this topology;
they do not change L1's full-viewport paint invariant.

- macOS with expanded navigation presents navigation, the traffic-light safe
  slot, and global tools as one continuous, immersive L1 surface.
- macOS with collapsed navigation presents two L1 fragments over L2: a top
  tool island containing the traffic-light reservation and global tools, and a
  leading navigation island. L2 remains fully painted below both fragments and
  scene headers receive only the required overlap avoidance inset.
- Windows and supported Linux with expanded navigation present one connected
  L1 frame composed of title bar and leading navigation.
- Windows and supported Linux with collapsed navigation retain a top title-bar
  fragment and a narrow leading rail fragment. They remain parts of the same
  L1 frame and may connect or overlap according to the platform's established
  drawing order. This is a frame topology, not a separate global-tool surface.
- In off-canvas navigation, the permanent L1 navigation fragment is absent
  from layout while L1 still paints beneath L2. A revealed temporary navigation
  pane remains an L1 fragment, and the native title-bar or traffic-light region
  stays fixed to the window.

The implementation should describe fragments, connections, geometry, and
drawing order rather than encode visual metaphors such as "F" or "island" as
platform-independent type names.

### Scene and transition rules

Feed, search, reader, and settings remain product scenes inside one shell
topology. Settings is an L2 scene replacement with its own L3 paper; it is not
a second shell or a full-screen modal over the feed.

The L1 topology and global tool area remain continuous during a scene change.
L2 may change scene atomically and L3 may use a reduced-motion-aware local
entrance transition. The shell must not retain two complete active scenes only
to animate between them.

One immutable shell layout result drives L1 fragments, L2 bounds, L3 bounds,
content avoidance insets, radius and shadow treatment, animation targets, and
hit regions. Individual scenes and controls must not calculate competing
platform geometry or maintain disconnected layout animation state.

The global tool plane has focused, bounded hit regions only. Its empty space
must not block content or native dragging. When temporary navigation or a
modal transient overlay is active, the shell preserves only the interactions
that remain valid and prevents background semantics from being bypassed.

## Module Responsibilities

The following responsibilities refine, rather than replace, the module
boundaries from ADR-0001 and ADR-0002:

- `ShellFrameTopology` describes L1 fragment relationships and their semantic
  presentation; it does not fetch product data or choose feature navigation.
- `ShellGlobalToolArea` owns global action identity, focus order, platform
  reservations, and presentation within an L1 fragment.
- `ShellChromeLayout` remains the platform chrome policy source of truth.
- `ShellFrameGeometry` or its direct successor remains the single source of
  resolved frame geometry. It must expose semantic insets and fragment bounds,
  not force product scenes to reconstruct platform measurements.
- Product scenes provide scene-specific command policy and own L2/L3 product
  composition. They do not own native chrome or duplicate global controls.

New modules must be deep, focused shell modules. This decision does not
authorize shallow wrappers or platform-specific copies of feed and settings
scenes.

## Migration and Verification

Migration is incremental and behavior-preserving until an explicitly reviewed
visual treatment change is introduced:

1. Characterize existing Windows and macOS geometry, global controls,
   traffic-light/caption reservations, settings composition, focus behavior,
   and reduced-motion behavior.
2. Introduce a semantic shell topology and global-tool ownership model without
   changing visible presentation.
3. Move existing shell commands into the one shell-owned global tool area;
   scenes declare policy instead of reimplementing controls.
4. Converge Windows connected-frame and macOS integrated/two-island rendering
   on the shared topology, then migrate settings and secondary reader scenes.
5. Delete duplicate scene or sidebar global controls only after their shell
   replacement is covered by focused tests.

Every migration batch must retain static analysis and relevant widget tests.
The focused test suite must cover at least:

- L1 full-surface paint and L2/L3 bounds across expanded, collapsed, and
  off-canvas states.
- Windows caption and drag reservations, title-bar/rail ordering, and narrow
  command overflow.
- macOS traffic-light safe metrics, integrated L1 presentation, and the two
  collapsed L1 fragments.
- Stable global-tool identity, keyboard traversal, and focus restoration as
  navigation and scenes change.
- Settings as an L2 scene replacement with one shell-owned tool area and no
  duplicate title bar.
- Reduced-motion, temporary-navigation, and transient-overlay hit/semantics
  behavior.

## Consequences

Positive consequences:

- The global controls remain stable while their L1 presentation changes.
- macOS two-island treatment and Windows connected-frame treatment share one
  product shell without being forced into identical visuals.
- L1 is always available beneath higher surfaces, preventing visible gaps in
  intermediate layout frames.
- Settings, reader, and feed scenes can share window behavior without copying
  platform chrome or global controls.

Costs and risks:

- Existing shell, settings, and sidebar geometry must be consolidated in small
  batches.
- Native traffic-light metrics, caption controls, drag regions, and narrow
  widths remain high-risk regression areas.
- Maintaining one stable global-tool identity during visual topology changes
  requires deliberate keys, focus handling, and characterization tests.

## Alternatives Considered

### Treat L4 as a fourth visual surface

Rejected. It would incorrectly introduce another background material and make
Windows title-bar fragments look like an overlay above L1 rather than a split
state of L1.

### Let each scene own its toolbar

Rejected. It duplicates commands, moves focus and semantics across navigation
states, and causes settings, reader, and feed chrome to drift apart.

### Use separate macOS and Windows product shells

Rejected. The difference is in L1 topology and native window reservations,
not in product-scene behavior. Separate shells would duplicate scenes,
navigation rules, and test coverage.

### Preserve current local ownership and only change colors or corners

Rejected. It would leave the actual source of topology and animation drift in
place while making the visual implementation more fragile.
