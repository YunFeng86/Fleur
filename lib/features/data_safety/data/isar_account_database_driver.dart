import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../../db/migrations.dart';
import '../../accounts/domain/account.dart';
import '../../../models/article.dart';
import '../../../models/category.dart';
import '../../../models/feed.dart';
import '../../../models/tag.dart';
import '../../../services/logging/app_logger.dart';
import '../../../utils/path_manager.dart';

enum DbOpenFailureKind {
  transient,
  environmental,
  recoveryRequired,
  dataMissing,
  ownershipMismatch,
}

enum AccountDbOpenMode { existing, initialize }

class DbOpenFailure implements Exception {
  const DbOpenFailure({
    required this.kind,
    required this.directory,
    required this.name,
    required this.error,
  });

  final DbOpenFailureKind kind;
  final String directory;
  final String name;
  final Object error;

  @override
  String toString() {
    return 'DbOpenFailure(kind: $kind, directory: $directory, name: $name, error: $error)';
  }
}

class AccountDbTarget {
  const AccountDbTarget({
    required this.accountId,
    required this.directory,
    required this.name,
    required this.isPrimary,
  });

  final String accountId;
  final String directory;
  final String name;
  final bool isPrimary;
}

typedef AccountDbTargetResolver =
    Future<AccountDbTarget> Function({
      required String accountId,
      String? dbName,
      required bool isPrimary,
    });

typedef AccountDbTargetOpener =
    Future<Isar> Function(AccountDbTarget target, AccountDbOpenMode mode);
typedef PendingMigrationsRunner = Future<void> Function(Isar isar);
typedef IsarOpenFn =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      required String name,
    });

PendingMigrationsRunner _pendingMigrationsRunner = runPendingMigrations;
IsarOpenFn _isarOpen = Isar.open;

void debugSetPendingMigrationsRunnerForTests(PendingMigrationsRunner runner) {
  _pendingMigrationsRunner = runner;
}

void debugResetPendingMigrationsRunnerForTests() {
  _pendingMigrationsRunner = runPendingMigrations;
}

@visibleForTesting
void debugSetIsarOpenForTests(IsarOpenFn opener) {
  _isarOpen = opener;
}

@visibleForTesting
void debugResetIsarOpenForTests() {
  _isarOpen = Isar.open;
}

Future<AccountDbTarget> resolveAccountDbTarget({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  if (isPrimary) {
    final loc = await PathManager.getIsarLocation();
    return AccountDbTarget(
      accountId: accountId,
      directory: loc.directory.path,
      name: loc.name,
      isPrimary: true,
    );
  }

  final dir = await PathManager.getDbDir();
  late final String name;
  try {
    name = Account.isolatedDatabaseNameFor(
      accountId: accountId,
      dbName: dbName,
    );
  } on FormatException catch (error) {
    throw DbOpenFailure(
      kind: DbOpenFailureKind.ownershipMismatch,
      directory: dir.path,
      name: dbName?.trim() ?? '',
      error: error,
    );
  }
  return AccountDbTarget(
    accountId: accountId,
    directory: dir.path,
    name: name,
    isPrimary: false,
  );
}

/// Open the Isar database for a given account.
///
/// - Primary account uses [PathManager.getIsarLocation] to avoid silent data
///   loss during migrations/legacy fallback.
/// - Other accounts always live under the new Support/db directory with a
///   stable per-account db name.
Future<Isar> openExistingIsarForAccount({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  final target = await resolveAccountDbTarget(
    accountId: accountId,
    dbName: dbName,
    isPrimary: isPrimary,
  );
  return openAccountDbTarget(target, AccountDbOpenMode.existing);
}

Future<Isar> initializeIsarForAccount({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  final target = await resolveAccountDbTarget(
    accountId: accountId,
    dbName: dbName,
    isPrimary: isPrimary,
  );
  return openAccountDbTarget(target, AccountDbOpenMode.initialize);
}

Future<Isar> openAccountDbTarget(
  AccountDbTarget target,
  AccountDbOpenMode mode,
) async {
  final schemas = [FeedSchema, ArticleSchema, CategorySchema, TagSchema];

  if (mode == AccountDbOpenMode.existing) {
    final dbFile = File(p.join(target.directory, '${target.name}.isar'));
    if (!await dbFile.exists()) {
      throw DbOpenFailure(
        kind: DbOpenFailureKind.dataMissing,
        directory: target.directory,
        name: target.name,
        error: StateError('Existing account database is missing.'),
      );
    }
  }

  final isar = await _openPreservingAccountData(
    schemas: schemas,
    directory: target.directory,
    name: target.name,
  );
  try {
    await _pendingMigrationsRunner(isar);
    return isar;
  } catch (e, s) {
    try {
      await isar.close();
    } catch (closeError, closeStack) {
      AppLogger.e(
        'Failed to close Isar after open finalization failure',
        tag: 'db',
        error: closeError,
        stackTrace: closeStack,
      );
    }
    Error.throwWithStackTrace(e, s);
  }
}

bool _containsAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}

String _openErrorText(Object error) {
  if (error is IsarError) {
    return error.message;
  }
  if (error is FileSystemException) {
    final parts = <String>[
      error.message,
      error.osError?.message ?? '',
      error.path ?? '',
    ];
    return parts.where((p) => p.trim().isNotEmpty).join(' | ');
  }
  return error.toString();
}

DbOpenFailureKind _classifyOpenFailure(Object error) {
  final text = _openErrorText(error).toLowerCase();

  // File locks / concurrent opens (common during fast account switching or when
  // the app is launched twice).
  if (_containsAny(text, <String>[
    'lock',
    'locked',
    'resource busy',
    'resource temporarily unavailable',
    'device or resource busy',
    'text file busy',
    'being used by another process',
    'in use',
    'already opened',
    'already been opened',
    'another instance',
    'mdbxerror (35)',
  ])) {
    return DbOpenFailureKind.transient;
  }

  // Environment issues: recovery (moving db / opening fresh) won't help.
  if (_containsAny(text, <String>[
    'permission denied',
    'access is denied',
    'operation not permitted',
    'read-only file system',
    'no such file or directory',
    'file system exception',
    'no space left on device',
  ])) {
    return DbOpenFailureKind.environmental;
  }

  // Corruption requires an explicit recovery workflow. Opening never mutates
  // or replaces the original account data.
  if (_containsAny(text, <String>[
    'corrupt',
    'checksum mismatch',
    'invalid database',
    'malformed database',
    'mdbx_corrupted',
  ])) {
    return DbOpenFailureKind.recoveryRequired;
  }

  // Default: preserve user data and avoid destructive recovery.
  return DbOpenFailureKind.environmental;
}

@visibleForTesting
DbOpenFailureKind debugClassifyDbOpenFailure(Object error) {
  return _classifyOpenFailure(error);
}

Future<Isar> _openPreservingAccountData({
  required List<CollectionSchema<dynamic>> schemas,
  required String directory,
  required String name,
}) async {
  try {
    return await _isarOpen(schemas, directory: directory, name: name);
  } catch (e, s) {
    var lastError = e;
    var lastStack = s;
    var kind = _classifyOpenFailure(e);

    if (kind == DbOpenFailureKind.transient) {
      const delays = <Duration>[
        Duration(milliseconds: 120),
        Duration(milliseconds: 240),
        Duration(milliseconds: 480),
        Duration(milliseconds: 960),
      ];

      for (var i = 0; i < delays.length; i++) {
        await Future<void>.delayed(delays[i]);
        try {
          final isar = await _isarOpen(
            schemas,
            directory: directory,
            name: name,
          );
          AppLogger.i('Isar open succeeded after retry #${i + 1}', tag: 'db');
          return isar;
        } catch (retryError, retryStack) {
          lastError = retryError;
          lastStack = retryStack;
          kind = _classifyOpenFailure(retryError);
          if (kind != DbOpenFailureKind.transient) break;
        }
      }
    }

    AppLogger.e(
      'Failed to open Isar DB; preserving account data',
      tag: 'db',
      error: lastError,
      stackTrace: lastStack,
    );
    throw DbOpenFailure(
      kind: kind,
      directory: directory,
      name: name,
      error: lastError,
    );
  }
}
