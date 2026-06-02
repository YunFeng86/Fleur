import 'dart:ffi' show Abi;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Isar backward compatibility', () {
    setUpAll(() async {
      await _initializeIsarCoreFromFlutterLibs();
    });

    test('Open legacy db (no autoTranslate) with current schemas', () async {
      final dir = await Directory.systemTemp.createTemp('fleur_isar_compat_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // ignore: best-effort cleanup
        }
      });

      const dbName = 'compat';

      // 1) Simulate a legacy database created before `autoTranslate` existed.
      final legacy = await Isar.open(
        [legacyFeedSchema, ArticleSchema, legacyCategorySchema, TagSchema],
        directory: dir.path,
        name: dbName,
      );

      final now = DateTime.now();
      await legacy.writeTxn(() async {
        await legacy.collection<LegacyCategory>().put(
          LegacyCategory()
            ..id = 42
            ..name = 'cat_legacy'
            ..showAiSummary = true
            ..createdAt = now
            ..updatedAt = now,
        );

        await legacy.collection<LegacyFeed>().put(
          LegacyFeed()
            ..id = 7
            ..url = 'https://example.com/rss'
            ..title = 'Legacy Feed'
            ..categoryId = 42
            ..showAiSummary = true
            ..createdAt = now
            ..updatedAt = now,
        );
      });
      await legacy.close();

      // 2) Reopen with the current (new) schemas and validate fields.
      late final Isar current;
      try {
        current = await Isar.open(
          [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
          directory: dir.path,
          name: dbName,
        );
      } catch (e) {
        fail(
          '🚨 Isar failed to open a legacy database with current schemas.\n'
          'This indicates a breaking schema change.\n'
          'Error: $e',
        );
      }

      final feed = await current.feeds.getByUrl('https://example.com/rss');
      expect(feed, isNotNull, reason: 'Legacy Feed record should exist');
      expect(feed!.url, equals('https://example.com/rss'));
      expect(feed.title, equals('Legacy Feed'));
      expect(feed.categoryId, equals(42));
      expect(
        feed.remoteId,
        isNull,
        reason:
            'Legacy DB should not have Feed.remoteId; it must deserialize as null.',
      );
      expect(feed.showAiSummary, isTrue);
      expect(
        feed.autoTranslate,
        isNull,
        reason:
            'Legacy DB should not have autoTranslate; it must deserialize as null.',
      );

      final category = await current.categorys.getByName('cat_legacy');
      expect(
        category,
        isNotNull,
        reason: 'Legacy Category record should exist',
      );
      expect(category!.name, equals('cat_legacy'));
      expect(
        category.remoteId,
        isNull,
        reason:
            'Legacy DB should not have Category.remoteId; it must deserialize as null.',
      );
      expect(category.showAiSummary, isTrue);
      expect(
        category.autoTranslate,
        isNull,
        reason:
            'Legacy DB should not have autoTranslate; it must deserialize as null.',
      );

      await current.close();
    });

    test(
      'Optional: open a real legacy .isar file fixture',
      () async {
        final fixturePath =
            Platform.environment['FLEUR_ISAR_FIXTURE']?.trim().isNotEmpty ==
                true
            ? Platform.environment['FLEUR_ISAR_FIXTURE']!.trim()
            : p.join(Directory.current.path, 'fleur.isar');

        final fixture = File(fixturePath);
        if (!fixture.existsSync()) {
          return;
        }

        final dir = await Directory.systemTemp.createTemp(
          'fleur_isar_fixture_',
        );
        addTearDown(() async {
          try {
            await dir.delete(recursive: true);
          } catch (_) {
            // ignore: best-effort cleanup
          }
        });

        // Keep the original file pristine (no lock files in repo).
        await fixture.copy(p.join(dir.path, 'fleur.isar'));

        late final Isar isar;
        try {
          isar = await Isar.open(
            [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
            directory: dir.path,
            name: 'fleur',
          );
        } catch (e) {
          fail(
            '🚨 Isar failed to open fixture file.\n'
            'Fixture: $fixturePath\n'
            'Error: $e',
          );
        }

        final feeds = await isar.feeds.where().limit(50).findAll();
        if (feeds.isNotEmpty) {
          for (final f in feeds) {
            expect(f.url.trim(), isNotEmpty);
          }
        }

        await isar.close();
      },
      skip: Platform.environment['RUN_ISAR_FIXTURE_TEST']?.trim() != '1',
    );
  });
}

Future<void> _initializeIsarCoreFromFlutterLibs() async {
  String? libraryPath;
  final pkgRoot = await _findPackageRoot('isar_community_flutter_libs');
  if (pkgRoot != null) {
    if (Platform.isWindows) {
      libraryPath = p.join(pkgRoot, 'windows', 'isar.dll');
    } else if (Platform.isLinux) {
      libraryPath = p.join(pkgRoot, 'linux', 'libisar.so');
    } else if (Platform.isMacOS) {
      libraryPath = p.join(pkgRoot, 'macos', 'libisar.dylib');
    }
  }

  if (libraryPath != null && File(libraryPath).existsSync()) {
    await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
    return;
  }

  // Fallback: allow downloading the correct library for unit tests.
  await Isar.initializeIsarCore(download: true);
}

Future<String?> _findPackageRoot(String packageName) async {
  try {
    final configFile = File(
      p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
    );
    if (!await configFile.exists()) return null;

    final raw = await configFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final packages = decoded['packages'];
    if (packages is! List) return null;

    Map? pkg;
    for (final item in packages) {
      if (item is Map && item['name'] == packageName) {
        pkg = item;
        break;
      }
    }
    if (pkg == null) return null;

    final rootUriRaw = pkg['rootUri'];
    if (rootUriRaw is! String || rootUriRaw.trim().isEmpty) return null;
    final rootUri = rootUriRaw.trim();

    final uri = Uri.parse(rootUri);
    if (uri.hasScheme && uri.scheme == 'file') {
      return uri.toFilePath();
    }

    // `rootUri` can be relative to the config file directory.
    return p.normalize(p.join(configFile.parent.path, rootUri));
  } catch (_) {
    return null;
  }
}

class LegacyFeed {
  Id id = Isar.autoIncrement;
  String url = '';
  String? title;
  int? categoryId;
  bool? showAiSummary;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
}

// Property IDs mirror the schema before `autoTranslate` existed.
final legacyFeedSchema = CollectionSchema(
  name: r'Feed',
  id: 8879644747771893978,
  properties: {
    r'categoryId': PropertySchema(
      id: 0,
      name: r'categoryId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'showAiSummary': PropertySchema(
      id: 14,
      name: r'showAiSummary',
      type: IsarType.bool,
    ),
    r'title': PropertySchema(id: 19, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'url': PropertySchema(id: 21, name: r'url', type: IsarType.string),
  },
  estimateSize: _legacyFeedEstimateSize,
  serialize: _legacyFeedSerialize,
  deserialize: _legacyFeedDeserialize,
  deserializeProp: _legacyFeedDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _legacyFeedGetId,
  getLinks: _legacyFeedGetLinks,
  attach: _legacyFeedAttach,
  version: Isar.version,
);

int _legacyFeedEstimateSize(
  LegacyFeed object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.url.length * 3;
  final title = object.title;
  if (title != null) {
    bytesCount += 3 + title.length * 3;
  }
  return bytesCount;
}

void _legacyFeedSerialize(
  LegacyFeed object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.categoryId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeBool(offsets[2], object.showAiSummary);
  writer.writeString(offsets[3], object.title);
  writer.writeDateTime(offsets[4], object.updatedAt);
  writer.writeString(offsets[5], object.url);
}

LegacyFeed _legacyFeedDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LegacyFeed();
  object.id = id;
  object.categoryId = reader.readLongOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.showAiSummary = reader.readBoolOrNull(offsets[2]);
  object.title = reader.readStringOrNull(offsets[3]);
  object.updatedAt = reader.readDateTime(offsets[4]);
  object.url = reader.readString(offsets[5]);
  return object;
}

P _legacyFeedDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  return switch (propertyId) {
    0 => (reader.readLongOrNull(offset) as P),
    1 => (reader.readDateTime(offset) as P),
    14 => (reader.readBoolOrNull(offset) as P),
    19 => (reader.readStringOrNull(offset) as P),
    20 => (reader.readDateTime(offset) as P),
    21 => (reader.readString(offset) as P),
    _ => throw IsarError('Unknown property with id $propertyId'),
  };
}

Id _legacyFeedGetId(LegacyFeed object) => object.id;

List<IsarLinkBase<dynamic>> _legacyFeedGetLinks(LegacyFeed object) =>
    const <IsarLinkBase<dynamic>>[];

void _legacyFeedAttach(IsarCollection<dynamic> col, Id id, LegacyFeed object) {
  object.id = id;
}

class LegacyCategory {
  Id id = Isar.autoIncrement;
  String name = '';
  bool? showAiSummary;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
}

// Property IDs mirror the schema before `autoTranslate` existed.
final legacyCategorySchema = CollectionSchema(
  name: r'Category',
  id: 5751694338128944171,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'showAiSummary': PropertySchema(
      id: 4,
      name: r'showAiSummary',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _legacyCategoryEstimateSize,
  serialize: _legacyCategorySerialize,
  deserialize: _legacyCategoryDeserialize,
  deserializeProp: _legacyCategoryDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _legacyCategoryGetId,
  getLinks: _legacyCategoryGetLinks,
  attach: _legacyCategoryAttach,
  version: Isar.version,
);

int _legacyCategoryEstimateSize(
  LegacyCategory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _legacyCategorySerialize(
  LegacyCategory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.name);
  writer.writeBool(offsets[2], object.showAiSummary);
  writer.writeDateTime(offsets[3], object.updatedAt);
}

LegacyCategory _legacyCategoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LegacyCategory();
  object.id = id;
  object.createdAt = reader.readDateTime(offsets[0]);
  object.name = reader.readString(offsets[1]);
  object.showAiSummary = reader.readBoolOrNull(offsets[2]);
  object.updatedAt = reader.readDateTime(offsets[3]);
  return object;
}

P _legacyCategoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  return switch (propertyId) {
    0 => (reader.readDateTime(offset) as P),
    3 => (reader.readString(offset) as P),
    4 => (reader.readBoolOrNull(offset) as P),
    8 => (reader.readDateTime(offset) as P),
    _ => throw IsarError('Unknown property with id $propertyId'),
  };
}

Id _legacyCategoryGetId(LegacyCategory object) => object.id;

List<IsarLinkBase<dynamic>> _legacyCategoryGetLinks(LegacyCategory object) =>
    const <IsarLinkBase<dynamic>>[];

void _legacyCategoryAttach(
  IsarCollection<dynamic> col,
  Id id,
  LegacyCategory object,
) {
  object.id = id;
}
