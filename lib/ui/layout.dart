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

const double kHomeListWidth = 420;

// Classic compact breakpoint; desktop can still be narrower when the window is
// resized, but this helps keep mobile behavior consistent.
const double kCompactWidth = 600;
