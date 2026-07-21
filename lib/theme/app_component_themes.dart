import 'package:flutter/material.dart';

import 'app_theme_profile.dart';
import 'fleur_icons.dart';
import 'fleur_theme_extensions.dart';

class AppComponentThemes {
  const AppComponentThemes._();

  static ThemeData apply({
    required ThemeData base,
    required AppThemeProfile profile,
    required FleurSurfaceTheme surfaces,
    required FleurStateTheme states,
    required FleurReaderTheme reader,
    required FleurDynamicColorTheme dynamicColor,
  }) {
    final scheme = base.colorScheme;
    final panelBorder = surfaces.subtleDivider.withAlpha(
      profile.isDesktop ? 64 : 72,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(profile.cardRadius),
      side: BorderSide(color: panelBorder),
    );

    WidgetStateProperty<Color?> stateLayer(Color baseColor) {
      return WidgetStateProperty.resolveWith((statesSet) {
        if (statesSet.contains(WidgetState.pressed)) return states.pressedTint;
        if (statesSet.contains(WidgetState.hovered)) return states.hoverTint;
        if (statesSet.contains(WidgetState.focused)) {
          return states.focusRing.withAlpha(32);
        }
        return baseColor == Colors.transparent ? null : baseColor;
      });
    }

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        surfaces,
        states,
        reader,
        dynamicColor,
      ],
      scaffoldBackgroundColor: surfaces.chrome,
      dividerTheme: DividerThemeData(
        color: surfaces.subtleDivider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: profile.centerCupertinoStyleTitles,
        surfaceTintColor: Colors.transparent,
        backgroundColor: surfaces.chrome,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaces.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withAlpha(28),
        shape: shape,
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surfaces.sidebar,
        surfaceTintColor: Colors.transparent,
        width: 320,
      ),
      listTileTheme: ListTileThemeData(
        dense: profile.isDesktop,
        visualDensity: profile.visualDensity,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.onSurface,
        selectedTileColor: states.selectionTint,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaces.card,
        isDense: profile.isDesktop,
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(profile.fieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(profile.fieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(profile.fieldRadius),
          borderSide: BorderSide(color: states.focusRing, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaces.card,
        selectedColor: states.selectionTint,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
        ),
        side: BorderSide(color: panelBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(profile.cardRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          overlayColor: stateLayer(Colors.transparent),
          iconSize: const WidgetStatePropertyAll(FleurIconMetrics.standard),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          overlayColor: stateLayer(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(profile.cardRadius - 2),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          overlayColor: stateLayer(Colors.transparent),
          side: WidgetStatePropertyAll(
            BorderSide(color: surfaces.subtleDivider),
          ),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
          backgroundColor: WidgetStatePropertyAll(scheme.primary),
          overlayColor: stateLayer(Colors.transparent),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: states.focusRing,
        selectionColor: states.selectionTint,
        selectionHandleColor: states.focusRing,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: ShapeDecoration(
          color: surfaces.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(profile.cardRadius - 2),
            side: BorderSide(color: surfaces.subtleDivider),
          ),
        ),
        textStyle: base.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(profile.persistentScrollbar),
        trackVisibility: const WidgetStatePropertyAll(false),
        radius: Radius.circular(profile.cardRadius),
        thickness: WidgetStatePropertyAll(profile.isDesktop ? 6 : 8),
        thumbColor: WidgetStateProperty.resolveWith((statesSet) {
          if (statesSet.contains(WidgetState.dragged)) {
            return states.scrollbarDrag;
          }
          if (statesSet.contains(WidgetState.hovered)) {
            return states.scrollbarHover;
          }
          return states.scrollbarIdle;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaces.floating,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        textStyle: base.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaces.floating),
          shadowColor: WidgetStatePropertyAll(scheme.shadow.withAlpha(42)),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(156, 0)),
          side: WidgetStatePropertyAll(
            BorderSide(color: surfaces.subtleDivider),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          iconColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          iconSize: const WidgetStatePropertyAll(FleurIconMetrics.compact),
          minimumSize: const WidgetStatePropertyAll(Size(156, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.only(start: 14, end: 16),
          ),
          overlayColor: stateLayer(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.floating,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaces.floating,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
