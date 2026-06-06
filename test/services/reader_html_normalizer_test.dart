import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/reader_html_normalizer.dart';

void main() {
  group('normalizeReaderHtmlForDisplay', () {
    test('keeps parsing supported math delimiters', () {
      final inline = normalizeReaderHtmlForDisplay(
        r'<p>Inline $a^2+b^2=c^2$ math.</p>',
      );
      final numericInline = normalizeReaderHtmlForDisplay(
        r'<p>Inline $2x+1$ math.</p>',
      );
      final block = normalizeReaderHtmlForDisplay(
        r'<p>Block $$E = mc^2$$ math.</p>',
      );
      final explicit = normalizeReaderHtmlForDisplay(
        r'<p>Escaped \(x+1\) and \[x^2\]</p>',
      );

      expect(inline, contains('<fleur-math'));
      expect(inline, contains('data-fleur-math="a^2+b^2=c^2"'));
      expect(inline, contains('data-fleur-math-display="inline"'));
      expect(numericInline, contains('data-fleur-math="2x+1"'));
      expect(block, contains('data-fleur-math="E = mc^2"'));
      expect(block, contains('data-fleur-math-display="block"'));
      expect(explicit, contains('data-fleur-math="x+1"'));
      expect(explicit, contains('data-fleur-math="x^2"'));
      expect(explicit, contains('data-fleur-math-display="block"'));
    });

    test('does not parse ordinary currency as single-dollar math', () {
      final revenue = normalizeReaderHtmlForDisplay(
        r'<p>Revenue moved from $5 to $7.</p>',
      );
      final costs = normalizeReaderHtmlForDisplay(
        r'<p>Costs range from $20,000 to $30,000.</p>',
      );
      final whitespace = normalizeReaderHtmlForDisplay(
        r'<p>This costs $ 5 and the note is $x $.</p>',
      );

      expect(revenue, isNot(contains('<fleur-math')));
      expect(costs, isNot(contains('<fleur-math')));
      expect(whitespace, isNot(contains('<fleur-math')));
    });

    test('skips invalid dollars before later valid math', () {
      final html = normalizeReaderHtmlForDisplay(
        r'<p>Price is $ 5, formula is $x+1$.</p>',
      );

      expect(html, contains(r'Price is $ 5'));
      expect(html, contains('data-fleur-math="x+1"'));
    });
  });
}
