# ADR-0005: Desktop Visual Alignment and Component Reuse

- Status: Accepted
- Date: 2026-08-30
- Decision owners: Fleur maintainers

## Context

Fleur's macOS and Windows/Linux shells should look like the same product while
respecting platform conventions. The product scenes, visual hierarchy, and
content density remain shared; the native window boundary and the treatment of
the shell may differ.

The first Windows/Linux shell pass exposed four alignment problems:

- A 48 logical pixel native title bar made the top of the application feel
  heavier than the macOS integrated chrome.
- The title-bar divider, the rail divider, and the content corner were painted
  by separate widgets. Their endpoints did not describe one continuous
  boundary, which could leave a visible seam or anti-aliased fringe at the
  L-shaped corner.
- The title bar used `chrome` while the Windows/Linux navigation used
  `sidebar`, despite both being parts of the same connected L1 frame.
- The settings title row and its navigation items used different horizontal
  insets, so the settings icon and label did not share the navigation baseline.

The same visual drift can recur if similar page headers, shell buttons, or
navigation items continue to own their own dimensions and state styling.

## Decision

### Shared visual identity with platform adaptation

macOS and Windows/Linux share the same Fleur design language:

- semantic colors, typography hierarchy, icon family, spacing scale, content
  widths, and interaction states;
- feed, reader, search, and settings scene structure;
- shell command identity and shared control primitives.

Platform profiles may change only the presentation required by the host:

- macOS keeps integrated traffic-light metrics, floating controls, and capsule
  rail surfaces;
- Windows/Linux keep a compact custom title bar, native caption controls, and a
  structural rail connected to the title bar;
- Linux uses the Windows frame topology as a conservative baseline but must not
  depend on Windows-only material effects.

Platform differences are expressed through `ShellChromeLayout`, theme profiles,
and named layout tokens. Product scenes must not fork into platform-specific
copies.

### Windows/Linux title-bar height

The native Windows/Linux title bar uses its own compact height token. The page
header height remains a separate scene token. Window drag and caption hit areas
must continue to fill the native title-bar height, and the caption slots must
remain stable at every supported scale factor.

### Continuous L-shaped frame boundary

Windows/Linux use one continuous L1 chrome surface for the title bar and the
left navigation. The content boundary is visible, but the frame is not given a
complete outer stroke:

- the title-bar bottom edge is visible from the content corner toward the
  caption area;
- the content leading edge is visible below the title bar;
- the two edges are joined by one anti-aliased rounded corner;
- no divider is placed between the title bar and the left navigation;
- no second widget paints an overlapping copy of the same edge.

The resolved frame geometry owns the boundary origin, corner radius, and
divider color. Content and navigation widgets consume that geometry and do not
reconstruct the L-shaped boundary independently.

macOS floating surfaces retain their existing independent capsule and overlay
treatment. This decision does not flatten the macOS shell into the Windows
frame.

### Shared surface ownership

For the connected Windows/Linux topology, the title bar and the navigation use
the same resolved L1 surface color. A small color difference between those two
regions is not used to communicate hierarchy; the content boundary provides
the separation. macOS may continue to use its existing surface relationships
where they support the integrated or floating treatment.

### Reuse before specialization

When two pages or components have the same visual and interaction contract,
they must share the component or the underlying design primitive. This applies
to:

- shell icon buttons and page-header action buttons;
- page-header title rows and their leading/trailing alignment rules;
- settings and feed navigation item states;
- platform geometry, surface colors, radii, and divider tokens.

Reuse does not require one oversized widget. A shared primitive may expose
slots or a small variant enum for content differences such as counts, arrows,
or title alignment. Business data, route behavior, and feature-specific
actions remain with the owning scene.

New platform-specific conditionals belong in the profile resolver or native
adapter. They must not be repeated in individual list items, settings tiles,
reader controls, or dialogs.

## Verification

The focused UI tests must verify:

- Windows/Linux title-bar height and caption slot stability;
- the continuous L-shaped boundary's origin, radius, and lack of duplicate
  dividers;
- matching title/navigation horizontal anchors in settings;
- identical connected L1 surface colors for Windows/Linux;
- unchanged macOS traffic-light metrics and floating rail behavior;
- shared shell control dimensions, focus behavior, and keyboard traversal.

Visual verification must include Windows 100%, 125%, 150%, and 200% scaling,
dark and light themes, narrow resize states, and Linux with compositor effects
unavailable.

