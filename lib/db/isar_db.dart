import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../models/rule.dart';
import '../models/tag.dart';
import '../utils/path_utils.dart';

Future<Isar> openIsar() async {
  final dir = await PathUtils.getAppDataDirectory();

  return Isar.open(
    [FeedSchema, ArticleSchema, CategorySchema, RuleSchema, TagSchema],
    directory: dir.path,
    name: 'flutter_reader',
  );
}
