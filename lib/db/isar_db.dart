import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../models/tag.dart';
import '../utils/path_utils.dart';
import 'migrations.dart';

Future<Isar> openIsar() async {
  final dir = await PathUtils.getAppDataDirectory();

  final isar = await Isar.open(
    [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
    directory: dir.path,
    name: 'flutter_reader',
  );

  // Run pending migrations after database is opened
  await runPendingMigrations(isar);

  return isar;
}
