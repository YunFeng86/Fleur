import 'package:flutter/material.dart';

import '../utils/platform.dart';
import '../widgets/global_nav_bar.dart';
import '../widgets/global_nav_rail.dart';
import 'global_nav.dart';
import 'layout.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentUri, required this.child});

  final Uri currentUri;
  final Widget child;

  bool _isArticleRoute(Uri uri) => uri.pathSegments.contains('article');

  bool _isReaderEmbedded({required double totalWidth, required Uri uri}) {
    if (!_isArticleRoute(uri)) return true;
    final contentWidth = effectiveContentWidth(totalWidth);
    if (isDesktop) {
      return desktopReaderEmbedded(desktopModeForWidth(contentWidth));
    }
    return contentWidth >= kCompactWidth;
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.sizeOf(context).width;
    final hideNavForReaderPage =
        _isArticleRoute(currentUri) &&
        !_isReaderEmbedded(totalWidth: totalWidth, uri: currentUri);

    if (hideNavForReaderPage) {
      // Dedicated reader pages should maximize content; they have their own
      // back button (ReaderView/ReaderScreen).
      return GlobalNavScope(hasGlobalNav: false, child: child);
    }

    final mode = globalNavModeForWidth(totalWidth);

    return switch (mode) {
      GlobalNavMode.rail => GlobalNavScope(
        hasGlobalNav: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: kGlobalNavRailWidth,
              child: GlobalNavRail(currentUri: currentUri),
            ),
            const VerticalDivider(width: kDividerWidth, thickness: 1),
            Expanded(child: child),
          ],
        ),
      ),
      GlobalNavMode.bottom => GlobalNavScope(
        hasGlobalNav: true,
        child: Column(
          children: [
            // When we render our own bottom nav outside the page Scaffold, the
            // default MediaQuery bottom padding (safe area) can create an extra
            // blank region above the nav bar on iOS. Remove it so the page body
            // uses the full height that's already constrained by this Column.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: child,
              ),
            ),
            const Divider(height: 1),
            // NavigationBar includes its own SafeArea internally. When used
            // outside Scaffold.bottomNavigationBar, we must remove the *top*
            // system padding from MediaQuery, otherwise NavigationBar's internal
            // SafeArea will add status-bar padding and create a large blank
            // region above the icons/labels (notably on iOS).
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: GlobalNavBar(currentUri: currentUri),
            ),
          ],
        ),
      ),
    };
  }
}
