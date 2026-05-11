import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('main Android manifest declares release networking permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final document = XmlDocument.parse(manifest.readAsStringSync());

    final permissions = document
        .findAllElements('uses-permission')
        .map((element) => element.getAttribute('android:name'))
        .whereType<String>()
        .toSet();

    expect(permissions, contains('android.permission.INTERNET'));
  });
}
