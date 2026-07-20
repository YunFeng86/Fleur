import 'package:flutter/material.dart';

/// Centralized motion tokens + reusable transitions.
///
/// Keep these fairly subtle: this app is list-heavy, and overly "cute" motion
/// will turn into noise fast.
class AppMotion {
  const AppMotion._();

  static const Duration short = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 300);
  static const Duration selectionTransitionDuration = short;

  static const Duration pageTransitionDuration = emphasized;
  static const Duration pageReverseTransitionDuration = Duration(
    milliseconds: 260,
  );

  static const Curve emphasizedDecelerate = Curves.easeOutCubic;
  static const Curve emphasizedAccelerate = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve selectionTransitionCurve = standardCurve;

  static bool reduceMotion(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;
    return mediaQuery.accessibleNavigation ||
        MediaQuery.disableAnimationsOf(context);
  }

  static Duration effectiveDuration(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;

  /// Section transitions tuned for pane-based navigation (Sidebar/List/Reader).
  ///
  /// Key idea: don't "fight" Hero pane motion.
  /// - Keep the *outgoing* page stationary when another route covers it.
  /// - Keep the *incoming* page minimal (fade only; no scale/slide).
  static Widget sectionTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (reduceMotion(context)) return child;

    // When this route is *under* another one (being covered), the framework
    // drives [secondaryAnimation]. Keep the outgoing page static so users can
    // perceive the List pane sliding into the Sidebar space.
    if (secondaryAnimation.status != AnimationStatus.dismissed) return child;

    final fade = CurvedAnimation(
      parent: animation,
      curve: standardCurve,
      reverseCurve: emphasizedAccelerate,
    );
    return FadeTransition(opacity: fade, child: child);
  }

  /// Material-ish fade-through: incoming fades/scales in while outgoing fades out.
  static Widget fadeThrough({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (reduceMotion(context)) return child;

    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: emphasizedDecelerate,
    );
    final fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: emphasizedAccelerate),
    );

    // Keep scale subtle; we only want to remove the "hard cut" feeling.
    final scaleIn = Tween<double>(begin: 0.985, end: 1).animate(fadeIn);

    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      ),
    );
  }
}
