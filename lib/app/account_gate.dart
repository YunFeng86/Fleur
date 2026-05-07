import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../db/isar_db.dart';
import '../providers/account_providers.dart';
import '../providers/core_providers.dart';
import '../providers/service_providers.dart';
import '../services/accounts/account.dart';
import '../services/data_integrity_startup_service.dart';
import '../services/logging/app_provider_observer.dart';
import '../widgets/app_scrollbar.dart';
import 'app.dart';

class AccountGate extends ConsumerStatefulWidget {
  const AccountGate({super.key});

  @override
  ConsumerState<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends ConsumerState<AccountGate> {
  Isar? _isar;
  String? _openedForAccountId;
  Future<void>? _opening;
  Object? _openError;
  StackTrace? _openErrorStack;
  String? _openErrorForAccountId;

  @override
  void dispose() {
    unawaited(_isar?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);
    final activeAccount = ref.watch(activeAccountProvider);
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

    // Ensure the correct Isar instance is opened for the active account.
    final shouldOpen = _openedForAccountId != activeAccount.id;
    final hasErrorForActive =
        _openError != null && _openErrorForAccountId == activeAccount.id;
    if (shouldOpen && _opening == null && !hasErrorForActive) {
      final openingForAccountId = activeAccount.id;
      _opening = _openFor(activeAccount)
          .catchError((e, st) {
            if (!mounted) return;
            setState(() {
              final currentAccountId = ref.read(activeAccountProvider).id;
              // Only keep the error if we're still trying to open the same
              // account (avoid stale errors after account switching).
              if (openingForAccountId == currentAccountId) {
                _openError = e;
                _openErrorStack = st is StackTrace ? st : null;
                _openErrorForAccountId = openingForAccountId;
              }
            });
          })
          .whenComplete(() {
            if (mounted) setState(() => _opening = null);
          });
    }

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

    final isar = _isar;
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

  Future<void> _openFor(Account account) async {
    final next = await openIsarForAccount(
      accountId: account.id,
      dbName: account.dbName,
      isPrimary: account.isPrimary,
    );
    unawaited(const DataIntegrityStartupService().runIfNeeded(next));
    final prev = _isar;
    _isar = next;
    _openedForAccountId = account.id;
    _openError = null;
    _openErrorStack = null;
    _openErrorForAccountId = null;
    if (prev != null) {
      // Close in background; Isar close can be slow on some platforms.
      unawaited(prev.close());
    }
  }
}
