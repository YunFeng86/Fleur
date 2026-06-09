// Layout constants tuned for desktop-first RSS reading.
//
// These are used to decide when to drop panes (3 -> 2 -> 2 -> 1) and to keep
// the reading measure comfortable.

// Minimum text measure for readable content.
// If the reader pane drops below this, we should switch to a different layout.
const double kMinReadingWidth = 450;

// Maximum text measure for comfortable reading. This value also participates
// in desktop layout decisions (when to drop panes).
const double kMaxReadingWidth = 700;

// Desktop fixed panes (in logical pixels).
const double kDesktopSidebarWidth = 260;
const double kDesktopListWidth = 460;
const double kPaneGap = 0;

// Non-desktop (tablet / narrow window) pane widths used in HomeScreen.
const double kHomeSidebarWidth = 280;
const double kHomeListWidth = 420;

// Classic compact breakpoint; desktop can still be narrower when the window is
// resized, but this helps keep mobile behavior consistent.
const double kCompactWidth = 600;

/// Desktop progressive layout modes (3 stages):
///
/// 1) threePane: sidebar + list + reader (reader reserved even when empty)
/// 2) splitListReader: list + reader (sidebar in drawer)
/// 3) listOnly: list only (sidebar in drawer; reader is a secondary page)
enum DesktopPaneMode { threePane, splitListReader, listOnly }

DesktopPaneMode desktopModeForWidth(
  double width, {
  double listWidth = kDesktopListWidth,
}) {
  // ELASTIC LOGIC:
  // We use MINIMUM widths to determine when to drop a pane.
  // This allows the reader view to be flexible (between kMinReadingWidth and infinity)
  // rather than rigidly requiring kMaxReadingWidth.

  // Stage 1 -> 2 boundary: Can we fit Sidebar + List + MinReader?
  // We check against kMinReadingWidth to allow the reader to start small and grow.
  final minFor3 =
      kDesktopSidebarWidth + listWidth + kMinReadingWidth + kPaneGap * 2;

  // Stage 2 -> 3 boundary: Can we fit List + MinReader?
  // We prioritizing keeping the Reader view visible over the Sidebar.
  final minForListReader = listWidth + kMinReadingWidth + kPaneGap;

  if (width >= minFor3) return DesktopPaneMode.threePane;
  if (width >= minForListReader) return DesktopPaneMode.splitListReader;
  // Fallback directly to list only (mobile/tablet-portrait style)
  // eliminating the "sidebar only" intermediate state.
  return DesktopPaneMode.listOnly;
}

bool desktopSidebarInline(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.threePane;

bool desktopSidebarInDrawer(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.splitListReader || mode == DesktopPaneMode.listOnly;

bool desktopReaderEmbedded(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.threePane ||
    mode == DesktopPaneMode.splitListReader;

/// Home (feeds) page column count for non-desktop layouts.
///
/// Unlike classic "600/1200" breakpoints, this keeps the reader pane at least
/// [kMinReadingWidth] wide when it is shown side-by-side.
int homeColumnsForWidth(double width) {
  final minFor2 = kHomeListWidth + kMinReadingWidth + kPaneGap;
  final minFor3 =
      kHomeSidebarWidth + kHomeListWidth + kMinReadingWidth + kPaneGap * 2;
  if (width >= minFor3) return 3;
  if (width >= minFor2) return 2;
  return 1;
}
