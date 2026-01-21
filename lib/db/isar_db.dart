import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../models/rule.dart';
import '../models/tag.dart';

Future<Isar> openIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [FeedSchema, ArticleSchema, CategorySchema, RuleSchema, TagSchema],
    directory: dir.path,
    name: 'flutter_reader',
  );
}
