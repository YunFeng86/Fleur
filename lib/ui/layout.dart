// Layout constants tuned for desktop-first RSS reading.
//
// These are used to decide when to drop panes (3 -> 2 -> 2 -> 1) and to keep
// the reading measure comfortable.

// Maximum text measure for comfortable reading. This value also participates
// in desktop layout decisions (when to drop panes).
// Minimum text measure for readable content.
// If the reader pane drops below this, we should switch to a different layout.
const double kMinReadingWidth = 450;

// Maximum text measure for comfortable reading. This value also participates
// in desktop layout decisions (when to drop panes).
const double kMaxReadingWidth = 700;

// Desktop fixed panes (in logical pixels).
const double kDesktopSidebarWidth = 260;
const double kDesktopListWidth = 400;
const double kDividerWidth = 1;

// Classic compact breakpoint; desktop can still be narrower when the window is
// resized, but this helps keep mobile behavior consistent.
const double kCompactWidth = 600;

/// Desktop progressive layout modes (4 stages):
///
/// 1) threePane: sidebar + list + reader (reader reserved even when empty)
/// 2) splitListReader: list + reader (sidebar in drawer)
/// 3) splitSidebarList: sidebar + list (reader is a secondary page)
/// 4) listOnly: list only (sidebar in drawer; reader is a secondary page)
enum DesktopPaneMode { threePane, splitListReader, splitSidebarList, listOnly }

DesktopPaneMode desktopModeForWidth(double width) {
  // ELASTIC LOGIC:
  // We use MINIMUM widths to determine when to drop a pane.
  // This allows the reader view to be flexible (between kMinReadingWidth and infinity)
  // rather than rigidly requiring kMaxReadingWidth.

  // Stage 1 -> 2 boundary: Can we fit Sidebar + List + MinReader?
  // We check against kMinReadingWidth to allow the reader to start small and grow.
  final minFor3 =
      kDesktopSidebarWidth +
      kDesktopListWidth +
      kMinReadingWidth +
      kDividerWidth * 2;

  // Stage 2 -> 3/4 boundary: Can we fit List + MinReader?
  // We prioritizing keeping the Reader view visible over the Sidebar.
  final minForListReader = kDesktopListWidth + kMinReadingWidth + kDividerWidth;

  // Stage 3 -> 4 boundary: Can we fit Sidebar + List?
  // This is a fallback if we can't fit List+Reader but still have decent width.
  // However, since minForListReader (400+450=850) is likely > minForSidebarList (260+400=660),
  // there is a zone (660 to 850) where we show Sidebar+List.
  final minForSidebarList =
      kDesktopSidebarWidth + kDesktopListWidth + kDividerWidth;

  if (width >= minFor3) return DesktopPaneMode.threePane;
  if (width >= minForListReader) return DesktopPaneMode.splitListReader;
  if (width >= minForSidebarList) return DesktopPaneMode.splitSidebarList;
  return DesktopPaneMode.listOnly;
}

bool desktopSidebarInline(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.threePane ||
    mode == DesktopPaneMode.splitSidebarList;

bool desktopSidebarInDrawer(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.splitListReader || mode == DesktopPaneMode.listOnly;

bool desktopReaderEmbedded(DesktopPaneMode mode) =>
    mode == DesktopPaneMode.threePane ||
    mode == DesktopPaneMode.splitListReader;
