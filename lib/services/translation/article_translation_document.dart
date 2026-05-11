import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'article_translation.dart';

class ArticleTranslationTarget {
  ArticleTranslationTarget._(this._element);

  final dom.Element _element;

  bool get hasTranslationMarker {
    return _element.attributes.containsKey('data-fleur-translation');
  }

  String get text {
    return _element.text.trim();
  }
}

class ArticleTranslationDocument {
  ArticleTranslationDocument._(this._body);

  factory ArticleTranslationDocument.parse(String html) {
    return ArticleTranslationDocument._(html_parser.parse(html).body);
  }

  final dom.Element? _body;

  bool get isEmpty => _body == null;

  String get html => (_body?.innerHtml ?? '').trim();

  List<ArticleTranslationTarget> targets() {
    final body = _body;
    if (body == null) return const <ArticleTranslationTarget>[];

    const selector =
        'p,li,h1,h2,h3,h4,h5,h6,blockquote,figcaption,caption,td,th';
    const nestedBlockSelector =
        'p,li,h1,h2,h3,h4,h5,h6,blockquote,figcaption,caption,td,th';
    final out = <ArticleTranslationTarget>[];

    for (final element in body.querySelectorAll(selector)) {
      final tag = element.localName?.toLowerCase() ?? '';
      if (tag.isEmpty) continue;
      if (_isInsideCodeBlock(element)) continue;
      if (element.attributes.containsKey('data-fleur-translation')) continue;
      if (_isContainerTag(tag) &&
          element.querySelector(nestedBlockSelector) != null) {
        continue;
      }
      out.add(ArticleTranslationTarget._(element));
    }
    return out;
  }

  void applyTranslation(
    ArticleTranslationTarget target,
    String translated, {
    required ArticleTranslationMode mode,
  }) {
    final element = target._element;
    if (mode == ArticleTranslationMode.traditional) {
      element.text = translated;
      return;
    }

    final tag = element.localName?.toLowerCase() ?? '';
    if (_appendTranslationInside(tag)) {
      final node = dom.Element.tag('div')
        ..attributes['data-fleur-translation'] = '1'
        ..attributes['style'] = 'opacity:0.75;font-style:italic;'
        ..text = translated;
      element.append(node);
      return;
    }

    final node = dom.Element.tag('p')
      ..attributes['data-fleur-translation'] = '1'
      ..attributes['style'] = 'opacity:0.75;font-style:italic;'
      ..text = translated;
    final parent = element.parent;
    if (parent == null) return;

    final index = parent.nodes.indexOf(element);
    if (index >= 0) {
      parent.nodes.insert(index + 1, node);
    } else {
      parent.append(node);
    }
  }

  static bool _isInsideCodeBlock(dom.Element element) {
    for (
      dom.Node? current = element.parent;
      current != null;
      current = current.parent
    ) {
      if (current is! dom.Element) continue;
      final tag = current.localName?.toLowerCase() ?? '';
      if (tag == 'pre' || tag == 'code') return true;
    }
    return false;
  }

  static bool _isContainerTag(String tag) {
    return tag == 'blockquote' ||
        tag == 'figcaption' ||
        tag == 'caption' ||
        tag == 'td' ||
        tag == 'th';
  }

  static bool _appendTranslationInside(String tag) {
    return tag == 'li' || _isContainerTag(tag);
  }
}
