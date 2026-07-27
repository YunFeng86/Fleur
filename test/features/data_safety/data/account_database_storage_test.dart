import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleur/features/data_safety/data/account_database_session_pool.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_driver.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/utils/path_manager.dart';

import '../../../test_utils/fake_path_provider_platform.dart';
import '../../../test_utils/isar_test_utils.dart';

class _FakeIsar extends Fake implements Isar {
  _FakeIsar({required this.name, required this.directory});

  @override
  final String name;

  @override
  final String directory;

  var closeCalls = 0;
  var deleteCalls = 0;
  var open = true;
  Completer<void>? closeCompleter;

  @override
  bool get isOpen => open;

  @override
  Future<bool> close({bool deleteFromDisk = false}) async {
    closeCalls++;
    if (deleteFromDisk) deleteCalls++;
    final completer = closeCompleter;
    if (completer != null) {
      await completer.future;
    }
    open = false;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('database open failure classification', () {
    test('treats MDBX resource unavailable as a transient lock conflict', () {
      final kind = debugClassifyDbOpenFailure(
        IsarError(
          'Cannot open Environment: MdbxError (35): '
          'Resource temporarily unavailable',
        ),
      );

      expect(kind, DbOpenFailureKind.transient);
    });

    test('preserves the database for unknown Isar errors', () {
      final kind = debugClassifyDbOpenFailure(
        IsarError('Unexpected database open failure'),
      );

      expect(kind, DbOpenFailureKind.environmental);
    });

    test('requires explicit recovery for corruption signals', () {
      final kind = debugClassifyDbOpenFailure(
        IsarError('Database file is corrupt'),
      );

      expect(kind, DbOpenFailureKind.recoveryRequired);
    });
  });

  group('AccountDbSessionManager', () {
    test(
      'coalesces concurrent acquires and closes after all leases release',
      () async {
        final completer = Completer<Isar>();
        var openCalls = 0;
        final manager = AccountDbSessionManager(
          resolveTarget:
              ({required accountId, dbName, required isPrimary}) async {
                return AccountDbTarget(
                  accountId: accountId,
                  directory: '/tmp/fleur-db',
                  name: dbName ?? 'fleur_$accountId',
                  isPrimary: isPrimary,
                );
              },
          openTarget: (target, mode) {
            openCalls++;
            return completer.future;
          },
        );

        final firstFuture = manager.acquireExistingForAccount(
          accountId: 'a',
          dbName: 'same',
          isPrimary: false,
        );
        final secondFuture = manager.acquireExistingForAccount(
          accountId: 'a',
          dbName: 'same',
          isPrimary: false,
        );

        await Future<void>.delayed(Duration.zero);
        expect(openCalls, 1);

        final isar = _FakeIsar(name: 'same', directory: '/tmp/fleur-db');
        completer.complete(isar);
        final leases = await Future.wait([firstFuture, secondFuture]);

        expect(leases[0].isar, same(isar));
        expect(leases[1].isar, same(isar));

        await leases[0].release();
        expect(isar.closeCalls, 0);

        await leases[0].release();
        expect(isar.closeCalls, 0);

        await leases[1].release();
        expect(isar.closeCalls, 1);
      },
    );

    test('rejects same Isar name with a different directory', () async {
      final manager = AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: accountId == 'a' ? '/tmp/one' : '/tmp/two',
                name: 'same',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          return _FakeIsar(name: target.name, directory: target.directory);
        },
      );

      final lease = await manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      addTearDown(lease.release);

      await expectLater(
        manager.acquireExistingForAccount(
          accountId: 'b',
          dbName: 'same',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (e) => e.kind,
            'kind',
            DbOpenFailureKind.ownershipMismatch,
          ),
        ),
      );
    });

    test('rejects same database target owned by another account', () async {
      final manager = AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: '/tmp/shared',
                name: 'same',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          return _FakeIsar(name: target.name, directory: target.directory);
        },
      );

      final lease = await manager.acquireExistingForAccount(
        accountId: 'account-a',
        dbName: 'same',
        isPrimary: false,
      );
      addTearDown(lease.release);

      await expectLater(
        manager.acquireExistingForAccount(
          accountId: 'account-b',
          dbName: 'same',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (error) => error.kind,
            'kind',
            DbOpenFailureKind.ownershipMismatch,
          ),
        ),
      );
    });

    test('deletion waits for leases and rejects new acquires', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'fleur_delete_reservation_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      await File(p.join(tempDir.path, 'same.isar')).writeAsBytes([1]);
      final opened = <_FakeIsar>[];
      final manager = AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: tempDir.path,
                name: dbName ?? 'fleur_$accountId',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          final isar = _FakeIsar(
            name: target.name,
            directory: target.directory,
          );
          opened.add(isar);
          return isar;
        },
      );

      final lease = await manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      var deletionCompleted = false;
      final deletion = manager
          .deleteIdleForAccount(
            accountId: 'a',
            dbName: 'same',
            isPrimary: false,
          )
          .whenComplete(() => deletionCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(deletionCompleted, isFalse);

      await expectLater(
        manager.acquireExistingForAccount(
          accountId: 'a',
          dbName: 'same',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (error) => error.kind,
            'kind',
            DbOpenFailureKind.transient,
          ),
        ),
      );

      final held = lease.isar as _FakeIsar;
      await lease.release();
      expect(await deletion, isTrue);
      expect(held.closeCalls, 1);
      expect(opened, hasLength(2));
      expect(opened.last.deleteCalls, 1);
    });

    test('deletion reservation covers database open and disk close', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'fleur_delete_open_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      await File(p.join(tempDir.path, 'same.isar')).writeAsBytes([1]);
      final openStarted = Completer<void>();
      final deleteIsar = _FakeIsar(name: 'same', directory: tempDir.path)
        ..closeCompleter = Completer<void>();
      final manager = AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: tempDir.path,
                name: dbName ?? 'fleur_$accountId',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          if (!openStarted.isCompleted) openStarted.complete();
          return deleteIsar;
        },
      );

      final deletion = manager.deleteIdleForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      await openStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(deleteIsar.deleteCalls, 1);

      await expectLater(
        manager.initializeForAccount(
          accountId: 'a',
          dbName: 'same',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (error) => error.kind,
            'kind',
            DbOpenFailureKind.transient,
          ),
        ),
      );

      deleteIsar.closeCompleter!.complete();
      expect(await deletion, isTrue);
    });

    test('deletion timeout releases its reservation', () async {
      final manager = AccountDbSessionManager(
        deletionWaitTimeout: const Duration(milliseconds: 20),
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: '/tmp/fleur-db',
                name: dbName ?? 'fleur_$accountId',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          return _FakeIsar(name: target.name, directory: target.directory);
        },
      );

      final lease = await manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );

      await expectLater(
        manager.deleteIdleForAccount(
          accountId: 'a',
          dbName: 'same',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (e) => e.kind,
            'kind',
            DbOpenFailureKind.transient,
          ),
        ),
      );

      final secondLease = await manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      await secondLease.release();
      await lease.release();
    });

    test('waits for close before reopening the same Isar name', () async {
      var openCalls = 0;
      final opened = <_FakeIsar>[];
      final manager = AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: '/tmp/fleur-db',
                name: dbName ?? 'fleur_$accountId',
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          openCalls++;
          final isar = _FakeIsar(
            name: target.name,
            directory: target.directory,
          );
          opened.add(isar);
          return isar;
        },
      );

      final firstLease = await manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      final firstIsar = firstLease.isar as _FakeIsar;
      firstIsar.closeCompleter = Completer<void>();

      final releaseFuture = firstLease.release();
      await Future<void>.delayed(Duration.zero);
      expect(firstIsar.closeCalls, 1);

      final secondLeaseFuture = manager.acquireExistingForAccount(
        accountId: 'a',
        dbName: 'same',
        isPrimary: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(openCalls, 1);

      firstIsar.closeCompleter!.complete();
      await releaseFuture;
      final secondLease = await secondLeaseFuture;
      addTearDown(secondLease.release);

      expect(openCalls, 2);
      expect(secondLease.isar, same(opened.last));
      expect(secondLease.isar, isNot(same(firstIsar)));
    });
  });

  group('openIsarForAccount', () {
    late PathProviderPlatform originalPlatform;
    late Directory tempDir;

    setUpAll(() async {
      originalPlatform = PathProviderPlatform.instance;
      await ensureIsarCoreInitialized();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('fleur_db_session_');
      final docs = await Directory(
        '${tempDir.path}/documents',
      ).create(recursive: true);
      final support = await Directory(
        '${tempDir.path}/support',
      ).create(recursive: true);
      final cache = await Directory(
        '${tempDir.path}/cache',
      ).create(recursive: true);
      final temporary = await Directory(
        '${tempDir.path}/temporary',
      ).create(recursive: true);
      PathProviderPlatform.instance = FakePathProviderPlatform(
        documentsPath: docs.path,
        supportPath: support.path,
        cachePath: cache.path,
        temporaryPath: temporary.path,
      );
      PathManager.resetForTests();
    });

    tearDown(() async {
      debugResetIsarOpenForTests();
      debugResetPendingMigrationsRunnerForTests();
      PathManager.resetForTests();
      PathProviderPlatform.instance = originalPlatform;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final preservingFailureCases =
        <({String label, IsarError error, DbOpenFailureKind expectedKind})>[
          (
            label: 'lock conflicts',
            error: IsarError(
              'Cannot open Environment: MdbxError (35): '
              'Resource temporarily unavailable',
            ),
            expectedKind: DbOpenFailureKind.transient,
          ),
          (
            label: 'unknown open errors',
            error: IsarError('Unexpected database open failure'),
            expectedKind: DbOpenFailureKind.environmental,
          ),
          (
            label: 'explicit corruption errors',
            error: IsarError('Database file is corrupt'),
            expectedKind: DbOpenFailureKind.recoveryRequired,
          ),
        ];

    test('existing mode does not create a missing account database', () async {
      var openCalled = false;
      debugSetIsarOpenForTests((
        schemas, {
        required directory,
        required name,
      }) async {
        openCalled = true;
        throw StateError('opener must not be called');
      });

      await expectLater(
        openExistingIsarForAccount(
          accountId: 'missing-account',
          dbName: 'missing_account',
          isPrimary: false,
        ),
        throwsA(
          isA<DbOpenFailure>().having(
            (error) => error.kind,
            'kind',
            DbOpenFailureKind.dataMissing,
          ),
        ),
      );

      expect(openCalled, isFalse);
      final dbDir = await PathManager.getDbDir();
      expect(
        await File('${dbDir.path}/missing_account.isar').exists(),
        isFalse,
      );
    });

    test(
      'remote accounts cannot resolve to the primary database name',
      () async {
        await expectLater(
          resolveAccountDbTarget(
            accountId: 'remote',
            dbName: 'FLEUR',
            isPrimary: false,
          ),
          throwsA(
            isA<DbOpenFailure>().having(
              (error) => error.kind,
              'kind',
              DbOpenFailureKind.ownershipMismatch,
            ),
          ),
        );
      },
    );

    test('initialize mode may create a new account database', () async {
      final isar = await initializeIsarForAccount(
        accountId: 'new-account',
        dbName: 'new_account',
        isPrimary: false,
      );
      await isar.close();

      final dbDir = await PathManager.getDbDir();
      expect(await File('${dbDir.path}/new_account.isar').exists(), isTrue);
    });

    for (final failureCase in preservingFailureCases) {
      test(
        '${failureCase.label} preserve the original database without fallback',
        () async {
          const dbName = 'preserved_account';
          const originalContents = 'sentinel account database contents';
          final dbDir = await PathManager.getDbDir();
          final originalFile = File('${dbDir.path}/$dbName.isar');
          await originalFile.writeAsString(originalContents);
          final openedNames = <String>[];

          debugSetIsarOpenForTests((
            schemas, {
            required directory,
            required name,
          }) async {
            openedNames.add(name);
            throw failureCase.error;
          });

          await expectLater(
            openExistingIsarForAccount(
              accountId: 'account-preserved',
              dbName: dbName,
              isPrimary: false,
            ),
            throwsA(
              isA<DbOpenFailure>().having(
                (error) => error.kind,
                'kind',
                failureCase.expectedKind,
              ),
            ),
          );

          expect(openedNames, isNotEmpty);
          expect(openedNames, everyElement(dbName));
          expect(await originalFile.exists(), isTrue);
          expect(await originalFile.readAsString(), originalContents);

          final entries = await dbDir.list(recursive: true).toList();
          expect(entries, hasLength(1));
          expect(entries.single.path, originalFile.path);
        },
      );
    }

    test(
      'closes Isar when migration setup fails after a successful open',
      () async {
        debugSetPendingMigrationsRunnerForTests((_) async {
          throw StateError('migration setup failed');
        });

        await expectLater(
          initializeIsarForAccount(
            accountId: 'account-a',
            dbName: 'migration_failure_cleanup',
            isPrimary: false,
          ),
          throwsA(anything),
        );

        final reopened = await Isar.open(
          [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
          directory: '${tempDir.path}/support/db',
          name: 'migration_failure_cleanup',
        );
        await reopened.close();
      },
    );
  });
}
