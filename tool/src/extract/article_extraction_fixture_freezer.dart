import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:fleur/services/extract/article_extractor_core.dart';

import 'article_extraction_audit.dart';

class ArticleExtractionFixtureFreezeOptions {
  const ArticleExtractionFixtureFreezeOptions({
    this.dryRun = false,
    this.htmlMode = ArticleExtractionFixtureHtmlMode.minimal,
    this.limit,
    this.timeout = const Duration(seconds: 12),
    this.userAgent,
    this.successLimit = 5,
    this.failureLimit = 3,
    this.maxMinimalFixtureBytes = 50 * 1024,
    this.failureReasons = _defaultFailureReasons,
    this.targetReasons,
  });

  final bool dryRun;
  final ArticleExtractionFixtureHtmlMode htmlMode;
  final int? limit;
  final Duration timeout;
  final String? userAgent;
  final int successLimit;
  final int failureLimit;
  final int maxMinimalFixtureBytes;
  final List<ArticleExtractionFailureReason> failureReasons;
  final List<ArticleExtractionFailureReason>? targetReasons;
}

enum ArticleExtractionFixtureHtmlMode { minimal, raw }

class ArticleExtractionFixtureCandidate {
  const ArticleExtractionFixtureCandidate({
    required this.category,
    required this.feedUrl,
    required this.url,
    required this.statusCode,
    required this.title,
    required this.expectedReason,
  });

  final String category;
  final String feedUrl;
  final String url;
  final int? statusCode;
  final String title;
  final ArticleExtractionFailureReason expectedReason;
}

class ArticleExtractionFrozenFixture {
  const ArticleExtractionFrozenFixture({
    required this.id,
    required this.category,
    required this.feedUrl,
    required this.url,
    required this.title,
    required this.sourceTitleHash,
    required this.expectedReason,
    required this.statusCode,
    required this.htmlPath,
    required this.sanitizedLength,
    required this.sourceSizeBytes,
    required this.fixtureSizeBytes,
    required this.htmlMode,
    required this.contentMode,
  });

  final String id;
  final String category;
  final String feedUrl;
  final String url;
  final String title;
  final String sourceTitleHash;
  final ArticleExtractionFailureReason expectedReason;
  final int? statusCode;
  final String htmlPath;
  final int sanitizedLength;
  final int sourceSizeBytes;
  final int fixtureSizeBytes;
  final ArticleExtractionFixtureHtmlMode htmlMode;
  final ArticleExtractionFixtureContentMode contentMode;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'category': category,
      'feedUrl': feedUrl,
      'url': url,
      'title': title,
      'sourceTitleHash': sourceTitleHash,
      'expectedReason': expectedReason.name,
      'statusCode': statusCode,
      'htmlPath': htmlPath,
      'sanitizedLength': sanitizedLength,
      'sourceSizeBytes': sourceSizeBytes,
      'fixtureSizeBytes': fixtureSizeBytes,
      'htmlMode': htmlMode.name,
      'contentMode': contentMode.name,
    };
  }
}

enum ArticleExtractionFixtureContentMode { redacted, raw }

class ArticleExtractionFixtureSkip {
  const ArticleExtractionFixtureSkip({
    required this.candidate,
    required this.message,
  });

  final ArticleExtractionFixtureCandidate candidate;
  final String message;
}

class ArticleExtractionFixtureFreezeResult {
  const ArticleExtractionFixtureFreezeResult({
    required this.planned,
    required this.frozen,
    required this.skipped,
    required this.dryRun,
  });

  final List<ArticleExtractionFixtureCandidate> planned;
  final List<ArticleExtractionFrozenFixture> frozen;
  final List<ArticleExtractionFixtureSkip> skipped;
  final bool dryRun;

  String toSummary() {
    final buffer = StringBuffer()
      ..writeln(
        dryRun
            ? 'Planned ${planned.length} article extraction fixtures.'
            : 'Wrote ${frozen.length} article extraction fixtures.',
      );

    if (frozen.isNotEmpty) {
      final sourceBytes = frozen.fold<int>(
        0,
        (sum, fixture) => sum + fixture.sourceSizeBytes,
      );
      final fixtureBytes = frozen.fold<int>(
        0,
        (sum, fixture) => sum + fixture.fixtureSizeBytes,
      );
      final percent = sourceBytes == 0
          ? '0.0'
          : ((fixtureBytes / sourceBytes) * 100).toStringAsFixed(1);
      buffer
        ..writeln(
          'Size: $sourceBytes source bytes -> $fixtureBytes fixture bytes '
          '($percent%).',
        )
        ..writeln()
        ..writeln('Frozen by reason:');
      final byReason = <ArticleExtractionFailureReason, int>{};
      for (final fixture in frozen) {
        byReason[fixture.expectedReason] =
            (byReason[fixture.expectedReason] ?? 0) + 1;
      }
      for (final entry in byReason.entries) {
        buffer.writeln('- ${entry.key.name}: ${entry.value}');
      }
      buffer.writeln();
      buffer.writeln('Frozen:');
      for (final fixture in frozen) {
        buffer.writeln(
          '- ${fixture.expectedReason.name}: ${fixture.id} '
          '${fixture.sourceSizeBytes} -> ${fixture.fixtureSizeBytes} bytes '
          '[${fixture.htmlMode.name}/${fixture.contentMode.name}] '
          '(${fixture.url})',
        );
      }
    }

    if (planned.isNotEmpty && dryRun) {
      buffer.writeln();
      buffer.writeln('Candidates:');
      for (final candidate in planned) {
        buffer.writeln(
          '- ${candidate.expectedReason.name}: ${candidate.title} '
          '(${candidate.url})',
        );
      }
    }

    if (skipped.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Skipped:');
      for (final skip in skipped) {
        buffer.writeln(
          '- ${skip.candidate.expectedReason.name}: '
          '${skip.candidate.url} - ${skip.message}',
        );
      }
    }

    return buffer.toString();
  }
}

class ArticleExtractionFixtureFreezer {
  ArticleExtractionFixtureFreezer({
    required ArticleExtractionAuditFetcher fetcher,
  }) : _fetcher = fetcher;

  final ArticleExtractionAuditFetcher _fetcher;

  Future<ArticleExtractionFixtureFreezeResult> freezeFromAuditReport({
    required String auditMarkdown,
    required Directory outputDirectory,
    ArticleExtractionFixtureFreezeOptions options =
        const ArticleExtractionFixtureFreezeOptions(),
  }) async {
    final candidatePool = _candidatePoolFromAuditReport(auditMarkdown, options);
    if (options.dryRun) {
      return ArticleExtractionFixtureFreezeResult(
        planned: _takeTargetCandidates(candidatePool, options),
        frozen: const [],
        skipped: const [],
        dryRun: true,
      );
    }

    final frozen = <ArticleExtractionFrozenFixture>[];
    final skipped = <ArticleExtractionFixtureSkip>[];
    final attempted = <ArticleExtractionFixtureCandidate>[];
    final frozenByReason = <ArticleExtractionFailureReason, int>{};

    for (final candidate in candidatePool) {
      if (_limitReached(frozen.length, options.limit)) break;

      final targetForReason = _targetLimit(candidate.expectedReason, options);
      final currentForReason = frozenByReason[candidate.expectedReason] ?? 0;
      if (currentForReason >= targetForReason) continue;

      attempted.add(candidate);
      final fixture = await _freezeCandidate(
        candidate,
        outputDirectory: outputDirectory,
        options: options,
      );

      if (fixture is _FrozenCandidate) {
        frozen.add(fixture.fixture);
        frozenByReason[candidate.expectedReason] = currentForReason + 1;
      } else if (fixture is _SkippedCandidate) {
        skipped.add(fixture.skip);
      }
    }

    await _writeManifest(outputDirectory, frozen);

    return ArticleExtractionFixtureFreezeResult(
      planned: attempted,
      frozen: frozen,
      skipped: skipped,
      dryRun: false,
    );
  }

  List<ArticleExtractionFixtureCandidate> planFromAuditReport(
    String auditMarkdown, {
    ArticleExtractionFixtureFreezeOptions options =
        const ArticleExtractionFixtureFreezeOptions(),
  }) {
    return _takeTargetCandidates(
      _candidatePoolFromAuditReport(auditMarkdown, options),
      options,
    );
  }

  Future<_CandidateFreezeOutcome> _freezeCandidate(
    ArticleExtractionFixtureCandidate candidate, {
    required Directory outputDirectory,
    required ArticleExtractionFixtureFreezeOptions options,
  }) async {
    final uri = Uri.tryParse(candidate.url);
    if (uri == null || !uri.hasScheme) {
      return _SkippedCandidate(candidate, 'Invalid article URL');
    }

    ArticleExtractionAuditFetchResult fetchResult;
    try {
      fetchResult = await _fetcher(
        uri,
        timeout: options.timeout,
        userAgent: options.userAgent,
      );
    } catch (e) {
      return _SkippedCandidate(candidate, 'Fetch failed: $e');
    }

    if (!_isSuccessStatus(fetchResult.statusCode) &&
        !_isDiagnosticStatus(fetchResult.statusCode)) {
      return _SkippedCandidate(
        candidate,
        'HTTP ${fetchResult.statusCode ?? 'unknown'}',
      );
    }

    final diagnostics = ArticleExtractorCore.diagnoseFromHtml(
      html: fetchResult.body,
      url: candidate.url,
      statusCode: fetchResult.statusCode,
    );
    var finalReason = candidate.expectedReason;
    if (diagnostics.reason != candidate.expectedReason) {
      final resolvedReason = _resolvedReasonForFixedCandidate(
        candidate.expectedReason,
        diagnostics.reason,
      );
      if (resolvedReason != null) {
        finalReason = resolvedReason;
      } else {
        return _SkippedCandidate(
          candidate,
          'Expected ${candidate.expectedReason.name}, got '
          '${diagnostics.reason.name}',
        );
      }
    }

    if (finalReason != candidate.expectedReason &&
        options.htmlMode == ArticleExtractionFixtureHtmlMode.raw) {
      return _SkippedCandidate(
        candidate,
        'Raw HTML changed reason: expected ${candidate.expectedReason.name}, '
        'got ${diagnostics.reason.name}',
      );
    }

    final id = _fixtureId(candidate);
    final sourceTitleHash = _sourceTitleHash(candidate.title);
    final contentMode = _contentModeFor(options.htmlMode);
    final manifestTitle =
        options.htmlMode == ArticleExtractionFixtureHtmlMode.raw
        ? candidate.title
        : _syntheticTitle(candidate.expectedReason, id);
    final sourceSizeBytes = _byteLength(fetchResult.body);
    final fixtureHtml = _fixtureHtml(
      fetchResult.body,
      mode: options.htmlMode,
      expectedReason: candidate.expectedReason,
      id: id,
    );
    final fixtureSizeBytes = _byteLength(fixtureHtml);
    final fixtureDiagnostics =
        options.htmlMode == ArticleExtractionFixtureHtmlMode.raw
        ? diagnostics
        : ArticleExtractorCore.diagnoseFromHtml(
            html: fixtureHtml,
            url: candidate.url,
            statusCode: fetchResult.statusCode,
          );
    if (fixtureDiagnostics.reason != finalReason) {
      final resolvedReason = _resolvedReasonForFixedCandidate(
        candidate.expectedReason,
        fixtureDiagnostics.reason,
      );
      if (resolvedReason == null) {
        return _SkippedCandidate(
          candidate,
          'Minimal HTML changed reason: expected '
          '${candidate.expectedReason.name}, got '
          '${fixtureDiagnostics.reason.name}',
        );
      }
      finalReason = resolvedReason;
    }
    if (fixtureDiagnostics.reason != finalReason) {
      return _SkippedCandidate(
        candidate,
        'Minimal HTML changed reason: expected '
        '${finalReason.name}, got ${fixtureDiagnostics.reason.name}',
      );
    }
    if (options.htmlMode == ArticleExtractionFixtureHtmlMode.minimal &&
        fixtureSizeBytes > options.maxMinimalFixtureBytes) {
      return _SkippedCandidate(
        candidate,
        'Minimal HTML too large: $fixtureSizeBytes bytes',
      );
    }

    final htmlPath = p.posix.join('html', '$id.html');
    final htmlFile = File(
      p.joinAll([outputDirectory.path, 'html', '$id.html']),
    );
    await htmlFile.parent.create(recursive: true);
    await htmlFile.writeAsString(fixtureHtml);

    return _FrozenCandidate(
      ArticleExtractionFrozenFixture(
        id: id,
        category: candidate.category,
        feedUrl: candidate.feedUrl,
        url: candidate.url,
        title: manifestTitle,
        sourceTitleHash: sourceTitleHash,
        expectedReason: finalReason,
        statusCode: fetchResult.statusCode,
        htmlPath: htmlPath,
        sanitizedLength: fixtureDiagnostics.sanitizedHtml.length,
        sourceSizeBytes: sourceSizeBytes,
        fixtureSizeBytes: fixtureSizeBytes,
        htmlMode: options.htmlMode,
        contentMode: contentMode,
      ),
    );
  }

  String _fixtureHtml(
    String html, {
    required ArticleExtractionFixtureHtmlMode mode,
    required ArticleExtractionFailureReason expectedReason,
    required String id,
  }) {
    return switch (mode) {
      ArticleExtractionFixtureHtmlMode.raw => html,
      ArticleExtractionFixtureHtmlMode.minimal => _minimalHtml(
        html,
        expectedReason: expectedReason,
        id: id,
      ),
    };
  }

  String _minimalHtml(
    String html, {
    required ArticleExtractionFailureReason expectedReason,
    required String id,
  }) {
    final doc = html_parser.parse(html);
    final sourceTitle = _sourceTitleFromDocument(doc);

    _removeCommentsAndDoctype(doc);
    _removeElements(doc);
    _trimMeta(doc);
    _normalizeNode(doc);
    final context = _FixtureRedactionContext(
      id: id,
      expectedReason: expectedReason,
      recoverableTitleOnly:
          expectedReason == ArticleExtractionFailureReason.titleOnly &&
          _hasStaticTextBeyondTitle(doc, sourceTitle),
    );
    _redactDocument(doc, context);
    _preserveDiagnosticSignal(doc, html, context);
    _preserveReasonShape(doc, context);
    _normalizeNode(doc);
    _removeExternalUrls(doc, context);

    return '${doc.outerHtml.replaceAll(RegExp(r'>\s+<'), '><').trim()}\n';
  }

  void _removeCommentsAndDoctype(dom.Node root) {
    for (final node in root.nodes.toList(growable: false)) {
      if (node.nodeType == dom.Node.COMMENT_NODE ||
          node.nodeType == dom.Node.DOCUMENT_TYPE_NODE) {
        node.remove();
        continue;
      }
      _removeCommentsAndDoctype(node);
    }
  }

  void _removeElements(dom.Document doc) {
    const selectors = [
      'script',
      'style',
      'noscript',
      'template',
      'svg',
      'canvas',
      'iframe',
      'link',
      'base',
      'source',
      'header',
      'footer',
      'nav',
      'aside',
      'form',
      'button',
      'input',
      'select',
      'textarea',
    ];
    for (final element in doc.querySelectorAll(selectors.join(','))) {
      element.remove();
    }
  }

  void _trimMeta(dom.Document doc) {
    for (final meta in doc.querySelectorAll('meta')) {
      final name = meta.attributes['name']?.toLowerCase();
      final property = meta.attributes['property']?.toLowerCase();
      final keep =
          name == 'generator' ||
          name == 'title' ||
          property == 'og:title' ||
          property == 'twitter:title';
      if (!keep) meta.remove();
    }
  }

  void _normalizeNode(dom.Node node) {
    if (node is dom.Text) {
      final collapsed = node.data.replaceAll(RegExp(r'\s+'), ' ');
      if (collapsed.trim().isEmpty) {
        node.remove();
      } else {
        node.data = collapsed;
      }
      return;
    }

    if (node is dom.Element) {
      _normalizeAttributes(node);
    }

    for (final child in node.nodes.toList(growable: false)) {
      _normalizeNode(child);
    }
  }

  void _normalizeAttributes(dom.Element element) {
    for (final key in element.attributes.keys.toList(growable: false)) {
      final name = key.toString();
      final value = element.attributes[key] ?? '';
      if (!_keepsAttribute(name) || _isLargeInlineResource(name, value)) {
        element.attributes.remove(key);
      } else if (name.toLowerCase() == 'class') {
        final compact = _compactClassValue(value);
        if (compact.isEmpty) {
          element.attributes.remove(key);
        } else {
          element.attributes[key] = compact;
        }
      }
    }
  }

  bool _keepsAttribute(String name) {
    final lower = name.toLowerCase();
    if (const {
      'id',
      'class',
      'src',
      'srcset',
      'alt',
      'title',
      'content',
      'name',
      'property',
    }.contains(lower)) {
      return true;
    }
    return const {
      'data-lazy-src',
      'data-src',
      'data-original',
      'data-srcset',
      'data-lazyload',
    }.contains(lower);
  }

  bool _isLargeInlineResource(String name, String value) {
    final lowerName = name.toLowerCase();
    final lower = value.toLowerCase();
    if ((lowerName == 'src' || lowerName == 'href') &&
        lower.startsWith('data:')) {
      return true;
    }
    return value.length > 2048;
  }

  String _compactClassValue(String value) {
    final kept = <String>[];
    for (final token in value.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();
      if (_keepsClassToken(lower)) kept.add(token);
    }
    return kept.join(' ');
  }

  bool _keepsClassToken(String token) {
    const exact = {
      'article',
      'article-content',
      'content',
      'entry-content',
      'keep-markdown-body',
      'markdown-body',
      'mdl-card__supporting-text',
      'post',
      'post-content',
      'post_detail',
    };
    if (exact.contains(token)) return true;
    const fragments = [
      'article',
      'comment',
      'content',
      'entry',
      'markdown',
      'post',
      'prev-next',
      'related',
      'share',
      'sidebar',
      'social',
      'toc',
    ];
    return fragments.any(token.contains);
  }

  void _preserveDiagnosticSignal(
    dom.Document doc,
    String html,
    _FixtureRedactionContext context,
  ) {
    if (context.expectedReason !=
        ArticleExtractionFailureReason.accessBlocked) {
      return;
    }
    final signal = _accessBlockedSignal(html);
    if (signal == null) return;

    final body = doc.body;
    if (body == null) return;
    final marker = dom.Element.tag('p')
      ..attributes['id'] = 'fixture-access-blocked-signal'
      ..text = signal;
    _fixtureContainer(body).nodes.insert(0, marker);
  }

  String? _accessBlockedSignal(String html) {
    final lower = html.toLowerCase();
    const patterns = [
      '403 forbidden',
      'access denied',
      'access forbidden',
      'request blocked',
      'not authorized',
      'unauthorized',
      'verify you are human',
      'captcha',
    ];
    for (final pattern in patterns) {
      if (lower.contains(pattern)) return pattern;
    }
    return null;
  }

  void _redactDocument(dom.Document doc, _FixtureRedactionContext context) {
    _redactHead(doc, context);
    final body = doc.body;
    if (body == null) return;
    _redactBodyNode(body, context);
  }

  void _redactHead(dom.Document doc, _FixtureRedactionContext context) {
    final head = doc.head;
    if (head == null) return;

    final titles = head.querySelectorAll('title');
    if (titles.isEmpty) {
      head.nodes.insert(
        0,
        dom.Element.tag('title')..text = context.syntheticTitle,
      );
    } else {
      for (final title in titles) {
        title.text = context.syntheticTitle;
      }
    }

    for (final meta in head.querySelectorAll('meta')) {
      if (meta.attributes.containsKey('content')) {
        meta.attributes['content'] = _redactedMetaContent(meta, context);
      }
      if (meta.attributes.containsKey('title')) {
        meta.attributes['title'] = context.syntheticTitle;
      }
    }
  }

  String _redactedMetaContent(
    dom.Element meta,
    _FixtureRedactionContext context,
  ) {
    final name = meta.attributes['name']?.toLowerCase();
    final content = (meta.attributes['content'] ?? '').toLowerCase();
    if (name == 'generator') {
      if (content.contains('wordpress')) return 'WordPress Fixture Generator';
      if (content.contains('hexo')) return 'Hexo Fixture Generator';
      if (content.contains('hugo')) return 'Hugo Fixture Generator';
      if (content.contains('halo')) return 'Halo Fixture Generator';
      return 'Fixture Generator';
    }
    return context.syntheticTitle;
  }

  void _redactBodyNode(dom.Node node, _FixtureRedactionContext context) {
    if (node is dom.Text) {
      final parent = node.parent;
      if (node.data.trim().isEmpty) {
        node.remove();
      } else {
        node.data = context.replacementText(parent);
      }
      return;
    }

    if (node is dom.Element) {
      _redactElementAttributes(node, context);
    }

    for (final child in node.nodes.toList(growable: false)) {
      _redactBodyNode(child, context);
    }
  }

  void _redactElementAttributes(
    dom.Element element,
    _FixtureRedactionContext context,
  ) {
    for (final key in element.attributes.keys.toList(growable: false)) {
      final name = key.toString().toLowerCase();
      if (name == 'alt') {
        element.attributes[key] = 'Fixture image';
      } else if (name == 'title') {
        element.attributes[key] = context.syntheticTitle;
      } else if (_isUrlAttribute(name)) {
        element.attributes[key] = _redactedUrlValue(name, context);
      } else if (name == 'id' || name == 'name') {
        element.attributes[key] = _redactedIdentifierValue(
          element.attributes[key] ?? '',
          context,
        );
      } else if (name == 'class') {
        element.attributes[key] = _redactedClassValue(
          element.attributes[key] ?? '',
        );
      }
    }
  }

  String _redactedIdentifierValue(
    String value,
    _FixtureRedactionContext context,
  ) {
    if (_keepsIdentifierValue(value)) return value;
    if (_looksSourceDerivedIdentifier(value)) {
      return context.nextAttributeToken('id');
    }
    return value;
  }

  bool _keepsIdentifierValue(String value) {
    const keep = {
      'articleContent',
      'comments',
      'content',
      'main',
      'post',
      'respond',
    };
    return keep.contains(value);
  }

  bool _looksSourceDerivedIdentifier(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('http') ||
        lower.contains('www.') ||
        lower.contains('_2f') ||
        lower.contains('%2f') ||
        lower.contains('%e') ||
        RegExp(r'[^\x00-\x7F]').hasMatch(value)) {
      return true;
    }
    if (value.length > 72) return true;
    return RegExp(
      r'(^|[_-])[a-z0-9-]+\.(com|cn|net|org|io|me|top|app|cc|eu|info|fun)([_-]|$)',
    ).hasMatch(lower);
  }

  String _redactedClassValue(String value) {
    final tokens = <String>[];
    for (final token in value.split(RegExp(r'\s+'))) {
      if (token.isEmpty || _looksSourceDerivedIdentifier(token)) continue;
      tokens.add(token);
    }
    return tokens.join(' ');
  }

  bool _isUrlAttribute(String name) {
    return const {
      'href',
      'src',
      'srcset',
      'data-lazy-src',
      'data-src',
      'data-original',
      'data-srcset',
      'data-lazyload',
    }.contains(name);
  }

  String _redactedUrlValue(String name, _FixtureRedactionContext context) {
    if (name == 'srcset' || name == 'data-srcset') {
      return '${context.nextImageUrl()} 1x, ${context.nextImageUrl()} 2x';
    }
    return context.nextImageUrl();
  }

  void _preserveReasonShape(
    dom.Document doc,
    _FixtureRedactionContext context,
  ) {
    final body = doc.body;
    if (body == null) return;

    switch (context.expectedReason) {
      case ArticleExtractionFailureReason.emptyContent:
        return;
      case ArticleExtractionFailureReason.titleOnly:
        if (context.recoverableTitleOnly) {
          _preserveRecoverableTitleOnly(body, context);
        } else {
          body.nodes
            ..clear()
            ..add(
              _articleWith([_elementWithText('h1', context.syntheticTitle)]),
            );
        }
        return;
      case ArticleExtractionFailureReason.loadingState:
        _fixtureContainer(body).nodes.insert(
          0,
          _elementWithText(
            'p',
            'please enable javascript loading please wait',
            id: 'fixture-loading-state-signal',
          ),
        );
        return;
      case ArticleExtractionFailureReason.accessBlocked:
        _fixtureContainer(body).nodes.insert(
          0,
          _elementWithText(
            'p',
            'access denied captcha request blocked',
            id: 'fixture-access-blocked-redacted-signal',
          ),
        );
        return;
      case ArticleExtractionFailureReason.lazyImageMissing:
        _preserveLazyImageMissing(body, context);
        return;
      case ArticleExtractionFailureReason.duplicateTitle:
        _preserveDuplicateTitle(body, context);
        return;
      case ArticleExtractionFailureReason.noiseAsBody:
        _preserveNoiseAsBody(body, context);
        return;
      case ArticleExtractionFailureReason.rssGarbled:
        _fixtureContainer(body).nodes.insert(
          0,
          _elementWithText('p', 'Fixture mojibake � ÃÂ signal.'),
        );
        return;
      case ArticleExtractionFailureReason.sanitizerLoss:
        _preserveSanitizerLoss(body);
        return;
      case ArticleExtractionFailureReason.none:
        _preserveNormalBody(body, context);
        return;
    }
  }

  void _preserveNormalBody(dom.Element body, _FixtureRedactionContext context) {
    final container = _fixtureContainer(body);
    if (container.text.trim().length >= 160) return;
    container.nodes.add(
      _elementWithText(
        'p',
        context.longBodyText('normal article extraction regression'),
      ),
    );
  }

  void _preserveDuplicateTitle(
    dom.Element body,
    _FixtureRedactionContext context,
  ) {
    final container = _fixtureContainer(body);
    container.nodes.insertAll(0, [
      _elementWithText('h1', context.syntheticTitle),
      _elementWithText('p', context.syntheticTitle),
      _elementWithText(
        'p',
        context.longBodyText('duplicate title regression body'),
      ),
    ]);
  }

  void _preserveRecoverableTitleOnly(
    dom.Element body,
    _FixtureRedactionContext context,
  ) {
    body.nodes
      ..clear()
      ..add(_articleWith([_elementWithText('h1', context.syntheticTitle)]))
      ..add(
        dom.Element.tag('div')
          ..attributes['class'] = 'post-content-content'
          ..nodes.addAll([
            _elementWithText(
              'p',
              context.longBodyText('recoverable title-only body'),
            ),
            _elementWithText(
              'p',
              context.longBodyText('recoverable title-only continuation'),
            ),
          ]),
      );
  }

  String _sourceTitleFromDocument(dom.Document doc) {
    final og = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (og != null && og.trim().isNotEmpty) return og.trim();
    final title = doc.querySelector('title')?.text;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    return '';
  }

  bool _hasStaticTextBeyondTitle(dom.Document doc, String title) {
    final body = doc.body;
    if (body == null) return false;

    var text = _normalizeFixtureText(body.text);
    final normalizedTitle = _normalizeFixtureText(title);
    if (normalizedTitle.isNotEmpty) {
      text = text.replaceAll(normalizedTitle, ' ');
    }
    final compact = text.replaceAll(RegExp(r'[\s.,;:!?]+'), '');
    return compact.length >= 160;
  }

  String _normalizeFixtureText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  void _preserveNoiseAsBody(
    dom.Element body,
    _FixtureRedactionContext context,
  ) {
    final container = _fixtureContainer(body);
    container.nodes.insertAll(0, [
      _elementWithText(
        'p',
        context.longBodyText('noise regression primary body'),
      ),
      _elementWithText(
        'p',
        context.longBodyText('noise regression continuation body'),
      ),
      _elementWithText(
        'div',
        'previous article next article related posts share comments',
        className: 'prev-next fixture-noise-block',
      ),
      _elementWithText(
        'div',
        'related posts share comments previous article next article',
        className: 'related-posts fixture-noise-block',
      ),
    ]);
  }

  void _preserveLazyImageMissing(
    dom.Element body,
    _FixtureRedactionContext context,
  ) {
    final container = _fixtureContainer(body);
    final image = container.querySelector('img') ?? dom.Element.tag('img');
    if (image.parent == null) container.nodes.insert(0, image);
    image.attributes
      ..remove('data-lazy-src')
      ..remove('data-src')
      ..remove('data-original')
      ..remove('srcset')
      ..remove('data-srcset')
      ..['src'] = '/img/b_ld.png'
      ..['data-lazyload'] = 'https://fixture.local/images/${context.id}.webp'
      ..['alt'] = 'Fixture image';
    if (container.text.trim().length < 120) {
      container.nodes.add(
        _elementWithText(
          'p',
          context.longBodyText('lazy image regression body'),
        ),
      );
    }
  }

  void _preserveSanitizerLoss(dom.Element body) {
    final container = _fixtureContainer(body);
    container.nodes.insertAll(0, [
      _elementWithText('p', 'Small visible fixture survivor.'),
      _elementWithText(
        'object',
        List<String>.filled(
          8,
          'Important fixture text disappears during sanitizing.',
        ).join(' '),
      ),
    ]);
  }

  void _removeExternalUrls(dom.Document doc, _FixtureRedactionContext context) {
    for (final element in doc.querySelectorAll('*')) {
      for (final key in element.attributes.keys.toList(growable: false)) {
        final value = element.attributes[key] ?? '';
        if (_containsExternalUrl(value)) {
          element.attributes[key] = _redactedUrlValue(
            key.toString().toLowerCase(),
            context,
          );
        }
      }
    }
  }

  bool _containsExternalUrl(String value) {
    final lower = value.toLowerCase();
    return (lower.contains('http://') ||
            lower.contains('https://') ||
            lower.contains('//')) &&
        !lower.contains('https://fixture.local/');
  }

  dom.Element _fixtureContainer(dom.Element body) {
    return body.querySelector(
          [
            '#articleContent',
            '.article-content.keep-markdown-body',
            '.article-content',
            '.markdown-body',
            '.post_detail .mdl-card__supporting-text',
            'article',
            'main',
          ].join(','),
        ) ??
        body;
  }

  dom.Element _articleWith(List<dom.Node> nodes) {
    return dom.Element.tag('article')..nodes.addAll(nodes);
  }

  dom.Element _elementWithText(
    String tag,
    String text, {
    String? id,
    String? className,
  }) {
    final element = dom.Element.tag(tag)..text = text;
    if (id != null) element.attributes['id'] = id;
    if (className != null) element.attributes['class'] = className;
    return element;
  }

  int _byteLength(String value) {
    return utf8.encode(value).length;
  }

  ArticleExtractionFixtureContentMode _contentModeFor(
    ArticleExtractionFixtureHtmlMode htmlMode,
  ) {
    return switch (htmlMode) {
      ArticleExtractionFixtureHtmlMode.minimal =>
        ArticleExtractionFixtureContentMode.redacted,
      ArticleExtractionFixtureHtmlMode.raw =>
        ArticleExtractionFixtureContentMode.raw,
    };
  }

  String _sourceTitleHash(String title) {
    return sha1.convert(utf8.encode(title)).toString();
  }

  Future<void> _writeManifest(
    Directory outputDirectory,
    List<ArticleExtractionFrozenFixture> frozen,
  ) async {
    await outputDirectory.create(recursive: true);
    final manifest = <String, Object?>{
      'version': 1,
      'generatedBy': 'tool/freeze_article_extraction_fixtures.dart',
      'samples': [for (final fixture in frozen) fixture.toJson()],
    };
    final manifestFile = File(p.join(outputDirectory.path, 'manifest.json'));
    await manifestFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  }

  List<ArticleExtractionFixtureCandidate> _candidatePoolFromAuditReport(
    String auditMarkdown,
    ArticleExtractionFixtureFreezeOptions options,
  ) {
    final fixtureCandidates = _parseExamples(
      auditMarkdown,
      sectionTitle: 'Fixture Candidates',
    );
    final topExamples = _parseExamples(
      auditMarkdown,
      sectionTitle: 'Top Examples',
    );
    final selected = <ArticleExtractionFixtureCandidate>[];
    final seen = <String>{};

    for (final reason in _orderedReasons(options)) {
      for (final candidate in fixtureCandidates.where(
        (candidate) => candidate.expectedReason == reason,
      )) {
        _addUniqueCandidate(selected, seen, candidate);
      }
      for (final candidate in topExamples.where(
        (candidate) => candidate.expectedReason == reason,
      )) {
        _addUniqueCandidate(selected, seen, candidate);
      }
    }

    return selected;
  }

  List<ArticleExtractionFixtureCandidate> _takeTargetCandidates(
    List<ArticleExtractionFixtureCandidate> candidatePool,
    ArticleExtractionFixtureFreezeOptions options,
  ) {
    final selected = <ArticleExtractionFixtureCandidate>[];
    final selectedByReason = <ArticleExtractionFailureReason, int>{};

    for (final candidate in candidatePool) {
      if (_limitReached(selected.length, options.limit)) break;

      final targetForReason = _targetLimit(candidate.expectedReason, options);
      final currentForReason = selectedByReason[candidate.expectedReason] ?? 0;
      if (currentForReason >= targetForReason) continue;

      selected.add(candidate);
      selectedByReason[candidate.expectedReason] = currentForReason + 1;
    }

    return selected;
  }

  void _addUniqueCandidate(
    List<ArticleExtractionFixtureCandidate> selected,
    Set<String> seen,
    ArticleExtractionFixtureCandidate candidate,
  ) {
    final key = '${candidate.expectedReason.name}\n${candidate.url}';
    if (!seen.add(key)) return;
    selected.add(candidate);
  }

  List<ArticleExtractionFixtureCandidate> _parseExamples(
    String markdown, {
    required String sectionTitle,
  }) {
    final section = _markdownSection(markdown, sectionTitle);
    if (section == null) return const [];

    final candidates = <ArticleExtractionFixtureCandidate>[];
    ArticleExtractionFailureReason? currentReason;
    for (final rawLine in const LineSplitter().convert(section)) {
      final line = rawLine.trim();
      if (line.startsWith('### ')) {
        currentReason = _reasonByName(line.substring(4).trim());
        continue;
      }
      if (currentReason == null ||
          !line.startsWith('|') ||
          _isTableHeaderOrDivider(line)) {
        continue;
      }

      final cells = _splitMarkdownTableRow(line);
      if (cells.length < 6) continue;

      final reason = _reasonByName(cells[5]) ?? currentReason;
      if (_isPlaceholderArticleUrl(cells[2])) continue;
      candidates.add(
        ArticleExtractionFixtureCandidate(
          category: cells[0],
          feedUrl: cells[1],
          url: cells[2],
          statusCode: _parseStatusCode(cells[3]),
          title: cells[4],
          expectedReason: reason,
        ),
      );
    }

    return candidates;
  }

  String? _markdownSection(String markdown, String sectionTitle) {
    final heading = RegExp(
      '^## ${RegExp.escape(sectionTitle)}\\s*\$',
      multiLine: true,
    ).firstMatch(markdown);
    if (heading == null) return null;

    RegExpMatch? nextHeading;
    for (final match in RegExp(
      r'^##\s+',
      multiLine: true,
    ).allMatches(markdown)) {
      if (match.start > heading.start) {
        nextHeading = match;
        break;
      }
    }

    return markdown.substring(heading.end, nextHeading?.start);
  }

  bool _isTableHeaderOrDivider(String line) {
    return line.contains('| Category |') ||
        RegExp(r'^\|\s*:?-{3,}').hasMatch(line);
  }

  List<String> _splitMarkdownTableRow(String row) {
    final trimmed = row.trim();
    final content = trimmed.substring(
      trimmed.startsWith('|') ? 1 : 0,
      trimmed.endsWith('|') ? trimmed.length - 1 : trimmed.length,
    );
    final cells = <String>[];
    final current = StringBuffer();
    for (var i = 0; i < content.length; i += 1) {
      final char = content[i];
      if (char == '\\' && i + 1 < content.length && content[i + 1] == '|') {
        current.write('|');
        i += 1;
        continue;
      }
      if (char == '|') {
        cells.add(current.toString().trim());
        current.clear();
        continue;
      }
      current.write(char);
    }
    cells.add(current.toString().trim());
    return cells;
  }

  ArticleExtractionFailureReason? _reasonByName(String name) {
    for (final reason in ArticleExtractionFailureReason.values) {
      if (reason.name == name.trim()) return reason;
    }
    return null;
  }

  int? _parseStatusCode(String status) {
    final trimmed = status.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  bool _isPlaceholderArticleUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return true;
    return uri.host.toLowerCase() == 'yoursite.com';
  }

  List<ArticleExtractionFailureReason> _orderedReasons(
    ArticleExtractionFixtureFreezeOptions options,
  ) {
    final targetReasons = options.targetReasons;
    if (targetReasons != null && targetReasons.isNotEmpty) {
      return _uniqueReasons(targetReasons);
    }
    return <ArticleExtractionFailureReason>[
      ArticleExtractionFailureReason.none,
      ...options.failureReasons,
    ];
  }

  List<ArticleExtractionFailureReason> _uniqueReasons(
    List<ArticleExtractionFailureReason> reasons,
  ) {
    final seen = <ArticleExtractionFailureReason>{};
    return [
      for (final reason in reasons)
        if (seen.add(reason)) reason,
    ];
  }

  int _targetLimit(
    ArticleExtractionFailureReason reason,
    ArticleExtractionFixtureFreezeOptions options,
  ) {
    final limit = reason == ArticleExtractionFailureReason.none
        ? options.successLimit
        : options.failureLimit;
    return limit <= 0 ? 1 : limit;
  }

  bool _limitReached(int count, int? limit) {
    return limit != null && count >= limit;
  }

  bool _isSuccessStatus(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  bool _isDiagnosticStatus(int? statusCode) {
    return statusCode == 401 || statusCode == 403 || statusCode == 451;
  }

  ArticleExtractionFailureReason? _resolvedReasonForFixedCandidate(
    ArticleExtractionFailureReason expected,
    ArticleExtractionFailureReason actual,
  ) {
    if (expected == ArticleExtractionFailureReason.titleOnly &&
        actual == ArticleExtractionFailureReason.none) {
      return ArticleExtractionFailureReason.none;
    }
    return null;
  }

  String _fixtureId(ArticleExtractionFixtureCandidate candidate) {
    final uri = Uri.tryParse(candidate.url);
    final pieces = <String>[
      _snakeReason(candidate.expectedReason),
      if (uri != null) uri.host.replaceFirst(RegExp(r'^www\.'), ''),
      if (uri != null) ...uri.pathSegments.take(3),
      if (uri == null) candidate.title,
    ];
    final base = pieces
        .join('_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final hash = sha1
        .convert(utf8.encode(candidate.url))
        .toString()
        .substring(0, 10);
    final trimmed = base.length > 80 ? base.substring(0, 80) : base;
    final stableBase = trimmed.replaceAll(RegExp(r'_+$'), '');
    return '${stableBase.isEmpty ? _snakeReason(candidate.expectedReason) : stableBase}_$hash';
  }

  static String _syntheticTitle(
    ArticleExtractionFailureReason reason,
    String id,
  ) {
    final label = reason.name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => ' ${match.group(0)!}',
    );
    final hash = sha1.convert(utf8.encode(id)).toString().substring(0, 8);
    return 'Fixture ${label[0].toUpperCase()}${label.substring(1)} $hash';
  }

  String _snakeReason(ArticleExtractionFailureReason reason) {
    return reason.name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }
}

class _FixtureRedactionContext {
  _FixtureRedactionContext({
    required this.id,
    required this.expectedReason,
    this.recoverableTitleOnly = false,
  }) : syntheticTitle = ArticleExtractionFixtureFreezer._syntheticTitle(
         expectedReason,
         id,
       );

  final String id;
  final ArticleExtractionFailureReason expectedReason;
  final bool recoverableTitleOnly;
  final String syntheticTitle;
  var _textIndex = 0;
  var _assetIndex = 0;

  String replacementText(dom.Element? parent) {
    final tag = parent?.localName?.toLowerCase();
    _textIndex += 1;
    if (_isHeadingTag(tag)) {
      return expectedReason == ArticleExtractionFailureReason.duplicateTitle ||
              expectedReason == ArticleExtractionFailureReason.titleOnly
          ? syntheticTitle
          : 'Fixture section heading $_textIndex';
    }

    return switch (expectedReason) {
      ArticleExtractionFailureReason.accessBlocked =>
        'access denied captcha request blocked',
      ArticleExtractionFailureReason.loadingState =>
        'please enable javascript loading please wait',
      ArticleExtractionFailureReason.noiseAsBody =>
        'Fixture article body paragraph $_textIndex for noise regression.',
      ArticleExtractionFailureReason.rssGarbled =>
        'Fixture garbled text � ÃÂ signal $_textIndex.',
      ArticleExtractionFailureReason.titleOnly =>
        recoverableTitleOnly
            ? 'Fixture article body paragraph $_textIndex for title-only recovery.'
            : syntheticTitle,
      ArticleExtractionFailureReason.duplicateTitle =>
        'Fixture duplicate title body text $_textIndex.',
      ArticleExtractionFailureReason.lazyImageMissing =>
        'Fixture lazy image body text $_textIndex.',
      ArticleExtractionFailureReason.sanitizerLoss =>
        'Important fixture text disappears during sanitizing $_textIndex.',
      ArticleExtractionFailureReason.emptyContent =>
        'Fixture empty content placeholder $_textIndex.',
      ArticleExtractionFailureReason.none =>
        'Fixture article body paragraph $_textIndex for extraction regression.',
    };
  }

  String longBodyText(String seed) {
    return List<String>.filled(
      4,
      'Fixture body paragraph for $seed.',
    ).join(' ');
  }

  String nextImageUrl() {
    _assetIndex += 1;
    return 'https://fixture.local/images/$id-$_assetIndex.webp';
  }

  String nextAttributeToken(String prefix) {
    _assetIndex += 1;
    return 'fixture-$prefix-$_assetIndex';
  }

  static bool _isHeadingTag(String? tag) {
    return const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag);
  }
}

sealed class _CandidateFreezeOutcome {
  const _CandidateFreezeOutcome();
}

class _FrozenCandidate extends _CandidateFreezeOutcome {
  const _FrozenCandidate(this.fixture);

  final ArticleExtractionFrozenFixture fixture;
}

class _SkippedCandidate extends _CandidateFreezeOutcome {
  _SkippedCandidate(ArticleExtractionFixtureCandidate candidate, String message)
    : skip = ArticleExtractionFixtureSkip(
        candidate: candidate,
        message: message,
      );

  final ArticleExtractionFixtureSkip skip;
}

const _defaultFailureReasons = <ArticleExtractionFailureReason>[
  ArticleExtractionFailureReason.titleOnly,
  ArticleExtractionFailureReason.loadingState,
  ArticleExtractionFailureReason.lazyImageMissing,
  ArticleExtractionFailureReason.accessBlocked,
  ArticleExtractionFailureReason.duplicateTitle,
  ArticleExtractionFailureReason.noiseAsBody,
];
