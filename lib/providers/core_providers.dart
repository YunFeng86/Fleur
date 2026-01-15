import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

// Overridden in `main.dart` after opening the database.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden in main()');
});

