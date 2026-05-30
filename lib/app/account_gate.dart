import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/isar_db.dart';
import '../providers/account_providers.dart';
import '../providers/core_providers.dart';
import '../providers/service_providers.dart';
import '../services/accounts/account.dart';
import '../services/accounts/account_store.dart';
import '../services/data_integrity_startup_service.dart';
import '../services/logging/app_provider_observer.dart';
import '../services/logging/app_logger.dart';
import '../widgets/app_scrollbar.dart';
import 'app.dart';

class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key, this.dbSessionManager});

  final AccountDbSessionManager? dbSessionManager;

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  ProviderSubscription<AsyncValue<AccountsState>>? _accountsSubscription;
  AccountDbLease? _lease;
  String? _openedForAccountId;
  Future<void>? _opening;
  String? _openingForAccountId;
  int _openGeneration = 0;
  Object? _openError;
  StackTrace? _openErrorStack;
  String? _openErrorForAccountId;

  @override
  void initState() {
    super.initState();
    _accountsSubscription = ref.listenManual<AsyncValue<AccountsState>>(
      accountsControllerProvider,
      (_, next) => _handleAccountsChanged(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _openGeneration++;
    _accountsSubscription?.close();
    unawaited(_lease?.release());
    super.dispose();
  }

  void _handleAccountsChanged(AsyncValue<AccountsState> accountsAsync) {
    final account = _activeAccountFromState(accountsAsync.valueOrNull);
    if (account == null) return;
    _ensureOpenFor(account);
  }

  Account? _activeAccountFromState(AccountsState? state) {
    if (state == null || state.accounts.isEmpty) return null;
    return state.findById(state.activeAccountId) ?? state.accounts.first;
  }

  void _ensureOpenFor(Account account) {
    if (_openedForAccountId == account.id && _lease != null) return;
    if (_opening != null && _openingForAccountId == account.id) return;
    if (_openError != null && _openErrorForAccountId == account.id) return;

    final generation = ++_openGeneration;
    final openingForAccountId = account.id;
    final opening = _openFor(account, generation)
        .catchError((e, st) {
          final stackTrace = st is StackTrace ? st : null;
          _logOpenFailure(account, e, stackTrace);
          if (!mounted || generation != _openGeneration) return;
          setState(() {
            final currentAccountId = _activeAccountFromState(
              ref.read(accountsControllerProvider).valueOrNull,
            )?.id;
            // Only keep the error if we're still trying to open the same
            // account (avoid stale errors after account switching).
            if (openingForAccountId == currentAccountId) {
              _openError = e;
              _openErrorStack = stackTrace;
              _openErrorForAccountId = openingForAccountId;
            }
          });
        })
        .whenComplete(() {
          if (!mounted || generation != _openGeneration) return;
          setState(() {
            _opening = null;
            _openingForAccountId = null;
          });
        });

    setState(() {
      _opening = opening;
      _openingForAccountId = openingForAccountId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);
    final notificationService = ref.watch(notificationServiceProvider);

    if (accountsAsync.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (accountsAsync.hasError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text(accountsAsync.error.toString())),
        ),
      );
    }

    final activeAccount = _activeAccountFromState(accountsAsync.valueOrNull);
    if (activeAccount == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final hasErrorForActive =
        _openError != null && _openErrorForAccountId == activeAccount.id;

    final opening = _opening;
    if (opening != null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final openError = _openError;
    if (openError != null && hasErrorForActive) {
      final kind = openError is DbOpenFailure ? openError.kind : null;
      final hint = switch (kind) {
        DbOpenFailureKind.transient =>
          '数据库可能正在被占用（例如同时打开了两个应用实例），或正在关闭中。请关闭其他实例后重试。',
        DbOpenFailureKind.environmental =>
          '数据库目录可能没有权限/磁盘空间不足/路径异常。请检查系统权限与存储空间后重试。',
        _ => '数据库打开失败，请重试或重启应用。',
      };
      final details = [
        openError.toString(),
        if (_openErrorStack != null) _openErrorStack.toString(),
      ].join('\n\n');

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('无法打开数据库', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 12),
                    Text(hint),
                    const SizedBox(height: 12),
                    const Text(
                      '错误详情：',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: AppScrollbar(
                        child: SingleChildScrollView(
                          child: SelectableText(details),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _openError = null;
                            _openErrorStack = null;
                            _openErrorForAccountId = null;
                          });
                          _ensureOpenFor(activeAccount);
                        },
                        child: const Text('重试'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isar = _lease?.isar;
    if (isar == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ProviderScope(
      key: ValueKey('account:${activeAccount.id}'),
      observers: const [AppProviderObserver()],
      overrides: [
        isarProvider.overrideWithValue(isar),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const App(),
    );
  }

  Future<void> _openFor(Account account, int generation) async {
    final manager = widget.dbSessionManager ?? AccountDbSessionManager.instance;
    final next = await manager.acquireForAccount(
      accountId: account.id,
      dbName: account.dbName,
      isPrimary: account.isPrimary,
    );
    if (!mounted || generation != _openGeneration) {
      await next.release();
      return;
    }

    unawaited(const DataIntegrityStartupService().runIfNeeded(next.isar));
    final prev = _lease;
    setState(() {
      _lease = next;
      _openedForAccountId = account.id;
      _openError = null;
      _openErrorStack = null;
      _openErrorForAccountId = null;
    });
    if (prev != null) {
      unawaited(prev.release());
    }
  }

  static void _logOpenFailure(
    Account account,
    Object error,
    StackTrace? stackTrace,
  ) {
    final kind = error is DbOpenFailure ? error.kind.name : null;
    AppLogger.e(
      'Account database open failed',
      tag: 'db',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': 'openAccountDatabase',
        'accountId': account.id,
        'accountType': account.type.wire,
        'isPrimary': account.isPrimary,
        'failureKind': kind,
      },
    );
  }
}
