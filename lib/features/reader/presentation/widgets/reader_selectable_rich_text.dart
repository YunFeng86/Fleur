import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A [RichText] variant for reader content that paints text selections using
/// line-level boxes instead of glyph-tight boxes.
class ReaderSelectableRichText extends RichText {
  ReaderSelectableRichText({
    super.key,
    required super.text,
    super.textAlign = TextAlign.start,
    super.textDirection,
    super.softWrap = true,
    super.overflow = TextOverflow.clip,
    super.textScaler = TextScaler.noScaling,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis = TextWidthBasis.parent,
    super.textHeightBehavior,
    super.selectionRegistrar,
    super.selectionColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.strut,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
  });

  final ui.BoxHeightStyle selectionHeightStyle;
  final ui.BoxWidthStyle selectionWidthStyle;

  @override
  ReaderSelectionRenderParagraph createRenderObject(BuildContext context) {
    assert(textDirection != null || debugCheckHasDirectionality(context));
    return ReaderSelectionRenderParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      registrar: selectionRegistrar,
      selectionColor: selectionColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderParagraph renderObject) {
    super.updateRenderObject(context, renderObject);
    if (renderObject is ReaderSelectionRenderParagraph) {
      renderObject
        ..selectionHeightStyle = selectionHeightStyle
        ..selectionWidthStyle = selectionWidthStyle;
    }
  }
}

class ReaderSelectionRenderParagraph extends RenderParagraph {
  ReaderSelectionRenderParagraph(
    super.text, {
    super.textAlign,
    required super.textDirection,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.children,
    super.selectionColor,
    super.registrar,
    ui.BoxHeightStyle selectionHeightStyle = ui.BoxHeightStyle.strut,
    ui.BoxWidthStyle selectionWidthStyle = ui.BoxWidthStyle.tight,
  }) : _selectionHeightStyle = selectionHeightStyle,
       _selectionWidthStyle = selectionWidthStyle;

  ui.BoxHeightStyle get selectionHeightStyle => _selectionHeightStyle;
  ui.BoxHeightStyle _selectionHeightStyle;
  set selectionHeightStyle(ui.BoxHeightStyle value) {
    if (_selectionHeightStyle == value) return;
    _selectionHeightStyle = value;
    markNeedsPaint();
  }

  ui.BoxWidthStyle get selectionWidthStyle => _selectionWidthStyle;
  ui.BoxWidthStyle _selectionWidthStyle;
  set selectionWidthStyle(ui.BoxWidthStyle value) {
    if (_selectionWidthStyle == value) return;
    _selectionWidthStyle = value;
    markNeedsPaint();
  }

  @override
  List<ui.TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
  }) {
    return super.getBoxesForSelection(
      selection,
      boxHeightStyle: boxHeightStyle == ui.BoxHeightStyle.tight
          ? selectionHeightStyle
          : boxHeightStyle,
      boxWidthStyle: boxWidthStyle == ui.BoxWidthStyle.tight
          ? selectionWidthStyle
          : boxWidthStyle,
    );
  }
}
