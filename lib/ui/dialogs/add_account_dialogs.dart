import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';

import '../../providers/account_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/accounts/account.dart';
import '../../services/logging/app_logger.dart';
import '../../services/logging/log_context.dart';
import '../../services/sync/google_reader/google_reader_connection_probe.dart';
import '../../services/sync/google_reader/google_reader_provider_profile.dart';
import '../../utils/context_extensions.dart';

enum _MinifluxAuthMode { apiToken, basicAuth }

enum _FeverAuthMode { apiKey, basicAuth }

Future<String?> showAddLocalAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: l10n.local);
  final nameFocus = FocusNode();
  String? nameError;
  if (!context.mounted) return null;
  final name = await showDialog<String?>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.addLocalAccount),
            content: TextField(
              controller: nameCtrl,
              focusNode: nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (nameError == null) return;
                setState(() => nameError = null);
              },
              onSubmitted: (_) {
                final trimmed = nameCtrl.text.trim();
                if (trimmed.isEmpty) {
                  setState(() => nameError = l10n.nameRequired);
                  FocusScope.of(dialogContext).requestFocus(nameFocus);
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: nameError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final trimmed = nameCtrl.text.trim();
                  if (trimmed.isEmpty) {
                    setState(() => nameError = l10n.nameRequired);
                    FocusScope.of(dialogContext).requestFocus(nameFocus);
                    return;
                  }
                  Navigator.of(dialogContext).pop(trimmed);
                },
                child: Text(l10n.add),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  nameFocus.dispose();

  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return null;

  final id = await ref
      .read(accountsControllerProvider.notifier)
      .addAccount(type: AccountType.local, name: trimmed);
  await ref.read(accountsControllerProvider.notifier).setActive(id);
  if (!context.mounted) return id;
  context.showSnack(l10n.done);
  return id;
}

Future<String?> showAddFeverAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;

  final nameCtrl = TextEditingController(text: l10n.fever);
  final baseUrlCtrl = TextEditingController();
  final apiKeyCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameFocus = FocusNode();
  final baseUrlFocus = FocusNode();
  final apiKeyFocus = FocusNode();
  final usernameFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool obscureApiKey = true;
  bool obscurePassword = true;
  var authMode = _FeverAuthMode.apiKey;
  var submitting = false;
  String? nameError;
  String? baseUrlError;
  String? apiKeyError;
  String? usernameError;
  String? passwordError;

  String? createdId;

  Future<void> submit(StateSetter setState, BuildContext dialogContext) async {
    if (submitting) return;
    final name = nameCtrl.text.trim();
    final baseUrl = baseUrlCtrl.text.trim();
    final apiKey = apiKeyCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text;
    final uri = Uri.tryParse(baseUrl);
    String? nextNameError;
    String? nextBaseUrlError;
    String? nextApiKeyError;
    String? nextUsernameError;
    String? nextPasswordError;

    if (name.isEmpty) nextNameError = l10n.nameRequired;
    if (baseUrl.isEmpty) {
      nextBaseUrlError = l10n.baseUrlRequired;
    } else if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      nextBaseUrlError = l10n.invalidBaseUrl;
    }
    switch (authMode) {
      case _FeverAuthMode.apiKey:
        if (apiKey.isEmpty) nextApiKeyError = l10n.apiKeyRequired;
        break;
      case _FeverAuthMode.basicAuth:
        if (username.isEmpty) nextUsernameError = l10n.usernameRequired;
        if (password.isEmpty) nextPasswordError = l10n.passwordRequired;
        break;
    }

    final hasErrors = switch (authMode) {
      _FeverAuthMode.apiKey =>
        nextNameError != null ||
            nextBaseUrlError != null ||
            nextApiKeyError != null,
      _FeverAuthMode.basicAuth =>
        nextNameError != null ||
            nextBaseUrlError != null ||
            nextUsernameError != null ||
            nextPasswordError != null,
    };

    if (hasErrors) {
      setState(() {
        nameError = nextNameError;
        baseUrlError = nextBaseUrlError;
        apiKeyError = nextApiKeyError;
        usernameError = nextUsernameError;
        passwordError = nextPasswordError;
      });
      if (nextNameError != null) {
        FocusScope.of(dialogContext).requestFocus(nameFocus);
      } else if (nextBaseUrlError != null) {
        FocusScope.of(dialogContext).requestFocus(baseUrlFocus);
      } else if (nextApiKeyError != null) {
        FocusScope.of(dialogContext).requestFocus(apiKeyFocus);
      } else if (nextUsernameError != null) {
        FocusScope.of(dialogContext).requestFocus(usernameFocus);
      } else if (nextPasswordError != null) {
        FocusScope.of(dialogContext).requestFocus(passwordFocus);
      }
      return;
    }

    setState(() {
      nameError = null;
      baseUrlError = null;
      apiKeyError = null;
      usernameError = null;
      passwordError = null;
      submitting = true;
    });
    try {
      final id = await ref
          .read(accountsControllerProvider.notifier)
          .addAccount(type: AccountType.fever, name: name, baseUrl: baseUrl);

      final store = ref.read(credentialStoreProvider);
      switch (authMode) {
        case _FeverAuthMode.apiKey:
          await store.setApiToken(id, AccountType.fever, apiKey);
          await store.deleteBasicAuth(id, AccountType.fever);
          break;
        case _FeverAuthMode.basicAuth:
          await store.setBasicAuth(
            id,
            AccountType.fever,
            username: username,
            password: password,
          );
          await store.deleteApiToken(id, AccountType.fever);
          break;
      }

      await ref.read(accountsControllerProvider.notifier).setActive(id);
      createdId = id;
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    } catch (e, s) {
      _logAddRemoteAccountFailure(
        accountType: AccountType.fever,
        authMode: authMode.name,
        baseUrl: baseUrl,
        error: e,
        stackTrace: s,
      );
      if (!dialogContext.mounted) return;
      setState(() => submitting = false);
      dialogContext.showSnack(l10n.errorMessage(e.toString()));
    }
  }

  if (!context.mounted) return null;
  try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(l10n.addFever),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (nameError == null) return;
                        setState(() => nameError = null);
                      },
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(baseUrlFocus),
                      decoration: InputDecoration(
                        labelText: l10n.fieldName,
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlCtrl,
                      focusNode: baseUrlFocus,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (baseUrlError == null) return;
                        setState(() => baseUrlError = null);
                      },
                      onSubmitted: (_) {
                        final nextFocus = authMode == _FeverAuthMode.apiKey
                            ? apiKeyFocus
                            : usernameFocus;
                        FocusScope.of(dialogContext).requestFocus(nextFocus);
                      },
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        hintText: l10n.feverBaseUrlHint,
                        errorText: baseUrlError,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.authenticationMethod,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.apiKey),
                          selected: authMode == _FeverAuthMode.apiKey,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              authMode = _FeverAuthMode.apiKey;
                              usernameError = null;
                              passwordError = null;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.usernamePassword),
                          selected: authMode == _FeverAuthMode.basicAuth,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              authMode = _FeverAuthMode.basicAuth;
                              apiKeyError = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.feverAuthHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (authMode == _FeverAuthMode.apiKey) ...[
                      TextField(
                        controller: apiKeyCtrl,
                        focusNode: apiKeyFocus,
                        obscureText: obscureApiKey,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (apiKeyError == null) return;
                          setState(() => apiKeyError = null);
                        },
                        onSubmitted: (_) =>
                            unawaited(submit(setState, dialogContext)),
                        decoration: InputDecoration(
                          labelText: l10n.apiKey,
                          errorText: apiKeyError,
                          suffixIcon: IconButton(
                            tooltip: obscureApiKey ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscureApiKey
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => obscureApiKey = !obscureApiKey),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: usernameCtrl,
                        focusNode: usernameFocus,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (usernameError == null) return;
                          setState(() => usernameError = null);
                        },
                        onSubmitted: (_) => FocusScope.of(
                          dialogContext,
                        ).requestFocus(passwordFocus),
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          errorText: usernameError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        focusNode: passwordFocus,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (passwordError == null) return;
                          setState(() => passwordError = null);
                        },
                        onSubmitted: (_) =>
                            unawaited(submit(setState, dialogContext)),
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          errorText: passwordError,
                          suffixIcon: IconButton(
                            tooltip: obscurePassword ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () => unawaited(submit(setState, dialogContext)),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameCtrl.dispose();
    baseUrlCtrl.dispose();
    apiKeyCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    nameFocus.dispose();
    baseUrlFocus.dispose();
    apiKeyFocus.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
  }

  final id = createdId;
  if (id == null) return null;
  if (!context.mounted) return id;
  context.showSnack(l10n.done);
  return id;
}

Future<String?> showAddMinifluxAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;

  final nameCtrl = TextEditingController(text: l10n.miniflux);
  final baseUrlCtrl = TextEditingController();
  final tokenCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameFocus = FocusNode();
  final baseUrlFocus = FocusNode();
  final tokenFocus = FocusNode();
  final usernameFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool obscureToken = true;
  bool obscurePassword = true;
  var authMode = _MinifluxAuthMode.apiToken;
  var submitting = false;
  String? nameError;
  String? baseUrlError;
  String? tokenError;
  String? usernameError;
  String? passwordError;

  String? createdId;

  Future<void> submit(StateSetter setState, BuildContext dialogContext) async {
    if (submitting) return;
    final name = nameCtrl.text.trim();
    final baseUrl = baseUrlCtrl.text.trim();
    final token = tokenCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text;
    final uri = Uri.tryParse(baseUrl);
    String? nextNameError;
    String? nextBaseUrlError;
    String? nextTokenError;
    String? nextUsernameError;
    String? nextPasswordError;

    if (name.isEmpty) nextNameError = l10n.nameRequired;
    if (baseUrl.isEmpty) {
      nextBaseUrlError = l10n.baseUrlRequired;
    } else if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      nextBaseUrlError = l10n.invalidBaseUrl;
    }
    switch (authMode) {
      case _MinifluxAuthMode.apiToken:
        if (token.isEmpty) nextTokenError = l10n.apiTokenRequired;
        break;
      case _MinifluxAuthMode.basicAuth:
        if (username.isEmpty) nextUsernameError = l10n.usernameRequired;
        if (password.isEmpty) nextPasswordError = l10n.passwordRequired;
        break;
    }

    final hasErrors = switch (authMode) {
      _MinifluxAuthMode.apiToken =>
        nextNameError != null ||
            nextBaseUrlError != null ||
            nextTokenError != null,
      _MinifluxAuthMode.basicAuth =>
        nextNameError != null ||
            nextBaseUrlError != null ||
            nextUsernameError != null ||
            nextPasswordError != null,
    };

    if (hasErrors) {
      setState(() {
        nameError = nextNameError;
        baseUrlError = nextBaseUrlError;
        tokenError = nextTokenError;
        usernameError = nextUsernameError;
        passwordError = nextPasswordError;
      });
      if (nextNameError != null) {
        FocusScope.of(dialogContext).requestFocus(nameFocus);
      } else if (nextBaseUrlError != null) {
        FocusScope.of(dialogContext).requestFocus(baseUrlFocus);
      } else if (nextTokenError != null) {
        FocusScope.of(dialogContext).requestFocus(tokenFocus);
      } else if (nextUsernameError != null) {
        FocusScope.of(dialogContext).requestFocus(usernameFocus);
      } else if (nextPasswordError != null) {
        FocusScope.of(dialogContext).requestFocus(passwordFocus);
      }
      return;
    }

    setState(() {
      nameError = null;
      baseUrlError = null;
      tokenError = null;
      usernameError = null;
      passwordError = null;
      submitting = true;
    });
    try {
      final id = await ref
          .read(accountsControllerProvider.notifier)
          .addAccount(type: AccountType.miniflux, name: name, baseUrl: baseUrl);

      final store = ref.read(credentialStoreProvider);
      switch (authMode) {
        case _MinifluxAuthMode.apiToken:
          await store.setApiToken(id, AccountType.miniflux, token);
          // Strict mode: only keep one auth mechanism on disk.
          await store.deleteBasicAuth(id, AccountType.miniflux);
          break;
        case _MinifluxAuthMode.basicAuth:
          await store.setBasicAuth(
            id,
            AccountType.miniflux,
            username: username,
            password: password,
          );
          await store.deleteApiToken(id, AccountType.miniflux);
          break;
      }

      await ref.read(accountsControllerProvider.notifier).setActive(id);
      createdId = id;
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    } catch (e, s) {
      _logAddRemoteAccountFailure(
        accountType: AccountType.miniflux,
        authMode: authMode.name,
        baseUrl: baseUrl,
        error: e,
        stackTrace: s,
      );
      if (!dialogContext.mounted) return;
      setState(() => submitting = false);
      dialogContext.showSnack(l10n.errorMessage(e.toString()));
    }
  }

  if (!context.mounted) return null;
  try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(l10n.addMiniflux),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (nameError == null) return;
                        setState(() => nameError = null);
                      },
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(baseUrlFocus),
                      decoration: InputDecoration(
                        labelText: l10n.fieldName,
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlCtrl,
                      focusNode: baseUrlFocus,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (baseUrlError == null) return;
                        setState(() => baseUrlError = null);
                      },
                      onSubmitted: (_) {
                        final nextFocus = authMode == _MinifluxAuthMode.apiToken
                            ? tokenFocus
                            : usernameFocus;
                        FocusScope.of(dialogContext).requestFocus(nextFocus);
                      },
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        hintText: l10n.minifluxBaseUrlHint,
                        errorText: baseUrlError,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.authenticationMethod,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.apiToken),
                          selected: authMode == _MinifluxAuthMode.apiToken,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              authMode = _MinifluxAuthMode.apiToken;
                              usernameError = null;
                              passwordError = null;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.usernamePassword),
                          selected: authMode == _MinifluxAuthMode.basicAuth,
                          onSelected: (v) {
                            if (!v) return;
                            setState(() {
                              authMode = _MinifluxAuthMode.basicAuth;
                              tokenError = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.minifluxAuthHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (authMode == _MinifluxAuthMode.apiToken) ...[
                      TextField(
                        controller: tokenCtrl,
                        focusNode: tokenFocus,
                        obscureText: obscureToken,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (tokenError == null) return;
                          setState(() => tokenError = null);
                        },
                        onSubmitted: (_) =>
                            unawaited(submit(setState, dialogContext)),
                        decoration: InputDecoration(
                          labelText: l10n.apiToken,
                          errorText: tokenError,
                          suffixIcon: IconButton(
                            tooltip: obscureToken ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscureToken
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => obscureToken = !obscureToken),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: usernameCtrl,
                        focusNode: usernameFocus,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (usernameError == null) return;
                          setState(() => usernameError = null);
                        },
                        onSubmitted: (_) => FocusScope.of(
                          dialogContext,
                        ).requestFocus(passwordFocus),
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          errorText: usernameError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        focusNode: passwordFocus,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (passwordError == null) return;
                          setState(() => passwordError = null);
                        },
                        onSubmitted: (_) =>
                            unawaited(submit(setState, dialogContext)),
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          errorText: passwordError,
                          suffixIcon: IconButton(
                            tooltip: obscurePassword ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () => unawaited(submit(setState, dialogContext)),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameCtrl.dispose();
    baseUrlCtrl.dispose();
    tokenCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    nameFocus.dispose();
    baseUrlFocus.dispose();
    tokenFocus.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
  }

  final id = createdId;
  if (id == null) return null;
  if (!context.mounted) return id;
  context.showSnack(l10n.done);
  return id;
}

Future<String?> showAddGoogleReaderAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: l10n.googleReaderApi);
  final baseUrlCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameFocus = FocusNode();
  final baseUrlFocus = FocusNode();
  final usernameFocus = FocusNode();
  final passwordFocus = FocusNode();
  var profileId = GoogleReaderProviderProfiles.autoId;
  var obscurePassword = true;
  var submitting = false;
  String? nameError;
  String? baseUrlError;
  String? usernameError;
  String? passwordError;
  String? createdId;

  Future<void> submit(StateSetter setState, BuildContext dialogContext) async {
    if (submitting) return;
    final name = nameCtrl.text.trim();
    final baseUrl = baseUrlCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text;
    final uri = Uri.tryParse(baseUrl);
    String? nextNameError;
    String? nextBaseUrlError;
    String? nextUsernameError;
    String? nextPasswordError;

    if (name.isEmpty) nextNameError = l10n.nameRequired;
    if (baseUrl.isEmpty) {
      nextBaseUrlError = l10n.baseUrlRequired;
    } else if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      nextBaseUrlError = l10n.invalidBaseUrl;
    }
    if (username.isEmpty) nextUsernameError = l10n.usernameRequired;
    if (password.isEmpty) nextPasswordError = l10n.passwordRequired;

    if (nextNameError != null ||
        nextBaseUrlError != null ||
        nextUsernameError != null ||
        nextPasswordError != null) {
      setState(() {
        nameError = nextNameError;
        baseUrlError = nextBaseUrlError;
        usernameError = nextUsernameError;
        passwordError = nextPasswordError;
      });
      if (nextNameError != null) {
        FocusScope.of(dialogContext).requestFocus(nameFocus);
      } else if (nextBaseUrlError != null) {
        FocusScope.of(dialogContext).requestFocus(baseUrlFocus);
      } else if (nextUsernameError != null) {
        FocusScope.of(dialogContext).requestFocus(usernameFocus);
      } else {
        FocusScope.of(dialogContext).requestFocus(passwordFocus);
      }
      return;
    }

    setState(() {
      nameError = null;
      baseUrlError = null;
      usernameError = null;
      passwordError = null;
      submitting = true;
    });
    try {
      final probe = GoogleReaderConnectionProbe(dio: ref.read(dioProvider));
      final probeResult = await probe.probe(
        baseUrl: baseUrl,
        username: username,
        password: password,
        profileId: profileId,
      );
      final id = await ref
          .read(accountsControllerProvider.notifier)
          .addAccount(
            type: AccountType.googleReader,
            name: name,
            baseUrl: probeResult.normalizedBaseUrl,
            profileId: probeResult.profile.id,
          );
      final store = ref.read(credentialStoreProvider);
      await store.setBasicAuth(
        id,
        AccountType.googleReader,
        username: username,
        password: password,
      );
      await store.deleteApiToken(id, AccountType.googleReader);
      await ref.read(accountsControllerProvider.notifier).setActive(id);
      createdId = id;
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    } catch (e, s) {
      _logAddRemoteAccountFailure(
        accountType: AccountType.googleReader,
        authMode: 'basicAuth',
        baseUrl: baseUrl,
        profileId: profileId,
        error: e,
        stackTrace: s,
      );
      if (!dialogContext.mounted) return;
      setState(() {
        submitting = false;
        if (e is GoogleReaderProbeException) {
          baseUrlError = e.message;
        }
      });
      dialogContext.showSnack(l10n.errorMessage(e.toString()));
    }
  }

  if (!context.mounted) return null;
  try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(l10n.addGoogleReaderApi),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(baseUrlFocus),
                      decoration: InputDecoration(
                        labelText: l10n.fieldName,
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: profileId,
                      decoration: const InputDecoration(labelText: 'Provider'),
                      items: [
                        const DropdownMenuItem(
                          value: GoogleReaderProviderProfiles.autoId,
                          child: Text('Auto'),
                        ),
                        for (final profile
                            in GoogleReaderProviderProfiles.values)
                          DropdownMenuItem(
                            value: profile.id,
                            child: Text(profile.displayName),
                          ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) => setState(
                              () => profileId =
                                  value ?? GoogleReaderProviderProfiles.autoId,
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlCtrl,
                      focusNode: baseUrlFocus,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(usernameFocus),
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        hintText: 'https://example.com/reader/api/0',
                        errorText: baseUrlError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      focusNode: usernameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(passwordFocus),
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        errorText: usernameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      focusNode: passwordFocus,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          unawaited(submit(setState, dialogContext)),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        errorText: passwordError,
                        suffixIcon: IconButton(
                          tooltip: obscurePassword ? l10n.show : l10n.hide,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () => unawaited(submit(setState, dialogContext)),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameCtrl.dispose();
    baseUrlCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    nameFocus.dispose();
    baseUrlFocus.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
  }

  final id = createdId;
  if (id == null) return null;
  if (!context.mounted) return id;
  context.showSnack(l10n.done);
  return id;
}

Future<void> showEditGoogleReaderAccountDialog(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  if (account.type != AccountType.googleReader) return;
  final l10n = AppLocalizations.of(context)!;
  final store = ref.read(credentialStoreProvider);
  ({String username, String password})? savedBasicAuth;
  try {
    savedBasicAuth = await store.getBasicAuth(
      account.id,
      AccountType.googleReader,
    );
  } catch (e, s) {
    _logGoogleReaderAccountConnectionFailure(
      operation: 'loadGoogleReaderCredentials',
      accountId: account.id,
      profileId: account.profileId,
      baseUrl: account.baseUrl ?? '',
      error: e,
      stackTrace: s,
    );
  }
  if (!context.mounted) return;

  final baseUrlCtrl = TextEditingController(text: account.baseUrl ?? '');
  final usernameCtrl = TextEditingController(text: savedBasicAuth?.username);
  final passwordCtrl = TextEditingController();
  var profileId =
      GoogleReaderProviderProfiles.isKnownProfileId(account.profileId)
      ? account.profileId!
      : GoogleReaderProviderProfiles.genericId;
  var obscurePassword = true;
  var testing = false;
  var submitting = false;
  var saved = false;
  String? baseUrlError;
  String? usernameError;
  String? passwordError;
  String? statusMessage;
  bool statusOk = false;

  bool isBusy() => testing || submitting;

  String? effectivePassword() {
    final entered = passwordCtrl.text;
    if (entered.isNotEmpty) return entered;
    return savedBasicAuth?.password;
  }

  Future<GoogleReaderProbeResult?> probeCurrent({
    required StateSetter setState,
    required BuildContext dialogContext,
    required String operation,
  }) async {
    if (isBusy()) return null;
    final baseUrl = baseUrlCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = effectivePassword();
    final uri = Uri.tryParse(baseUrl);
    String? nextBaseUrlError;
    String? nextUsernameError;
    String? nextPasswordError;

    if (baseUrl.isEmpty) {
      nextBaseUrlError = l10n.baseUrlRequired;
    } else if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      nextBaseUrlError = l10n.invalidBaseUrl;
    }
    if (username.isEmpty) nextUsernameError = l10n.usernameRequired;
    if (password == null || password.isEmpty) {
      nextPasswordError = l10n.passwordRequired;
    }

    if (nextBaseUrlError != null ||
        nextUsernameError != null ||
        nextPasswordError != null) {
      setState(() {
        baseUrlError = nextBaseUrlError;
        usernameError = nextUsernameError;
        passwordError = nextPasswordError;
        statusMessage = null;
        statusOk = false;
      });
      return null;
    }

    setState(() {
      baseUrlError = null;
      usernameError = null;
      passwordError = null;
      statusMessage = null;
      statusOk = false;
      if (operation == 'testGoogleReaderConnection') {
        testing = true;
      } else {
        submitting = true;
      }
    });

    try {
      final probe = GoogleReaderConnectionProbe(dio: ref.read(dioProvider));
      return await probe.probe(
        baseUrl: baseUrl,
        username: username,
        password: password!,
        profileId: profileId,
      );
    } catch (e, s) {
      _logGoogleReaderAccountConnectionFailure(
        operation: operation,
        accountId: account.id,
        profileId: profileId,
        baseUrl: baseUrl,
        error: e,
        stackTrace: s,
      );
      if (!dialogContext.mounted) return null;
      final message = e is GoogleReaderProbeException
          ? e.message
          : 'Google Reader connection failed.';
      setState(() {
        if (e is GoogleReaderProbeException) {
          baseUrlError = e.message;
        }
        statusMessage = message;
        statusOk = false;
        testing = false;
        submitting = false;
      });
      dialogContext.showSnack(l10n.errorMessage(message));
      return null;
    }
  }

  Future<void> testConnection(
    StateSetter setState,
    BuildContext dialogContext,
  ) async {
    final result = await probeCurrent(
      setState: setState,
      dialogContext: dialogContext,
      operation: 'testGoogleReaderConnection',
    );
    if (result == null || !dialogContext.mounted) return;
    setState(() {
      testing = false;
      statusOk = true;
      final displayName = result.displayName?.trim();
      statusMessage =
          'Connected: ${result.profile.displayName}'
          '${displayName == null || displayName.isEmpty ? '' : ' - $displayName'}';
    });
  }

  Future<void> saveConnection(
    StateSetter setState,
    BuildContext dialogContext,
  ) async {
    final result = await probeCurrent(
      setState: setState,
      dialogContext: dialogContext,
      operation: 'updateGoogleReaderConnection',
    );
    if (result == null) return;
    try {
      final username = usernameCtrl.text.trim();
      final password = effectivePassword()!;
      await ref
          .read(accountsControllerProvider.notifier)
          .updateAccountConnection(
            accountId: account.id,
            baseUrl: result.normalizedBaseUrl,
            profileId: result.profile.id,
          );
      await store.setBasicAuth(
        account.id,
        AccountType.googleReader,
        username: username,
        password: password,
      );
      await store.deleteApiToken(account.id, AccountType.googleReader);
      saved = true;
      if (!dialogContext.mounted) return;
      FocusScope.of(dialogContext).unfocus();
      Navigator.of(dialogContext).pop();
    } catch (e, s) {
      _logGoogleReaderAccountConnectionFailure(
        operation: 'saveGoogleReaderConnection',
        accountId: account.id,
        profileId: result.profile.id,
        baseUrl: result.normalizedBaseUrl,
        error: e,
        stackTrace: s,
      );
      if (!dialogContext.mounted) return;
      setState(() {
        submitting = false;
        statusMessage = 'Google Reader connection save failed.';
        statusOk = false;
      });
      dialogContext.showSnack(
        l10n.errorMessage('Google Reader connection save failed.'),
      );
    }
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final busy = isBusy();
            final scheme = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              scrollable: true,
              title: const Text('Google Reader connection'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: profileId,
                      decoration: const InputDecoration(labelText: 'Provider'),
                      items: [
                        const DropdownMenuItem(
                          value: GoogleReaderProviderProfiles.autoId,
                          child: Text('Auto'),
                        ),
                        for (final profile
                            in GoogleReaderProviderProfiles.values)
                          DropdownMenuItem(
                            value: profile.id,
                            child: Text(profile.displayName),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              profileId =
                                  value ?? GoogleReaderProviderProfiles.autoId;
                              statusMessage = null;
                              statusOk = false;
                            }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlCtrl,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      onChanged: (_) {
                        if (baseUrlError == null && statusMessage == null) {
                          return;
                        }
                        setState(() {
                          baseUrlError = null;
                          statusMessage = null;
                          statusOk = false;
                        });
                      },
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).nextFocus(),
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        hintText: 'https://example.com/reader/api/0',
                        errorText: baseUrlError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (usernameError == null && statusMessage == null) {
                          return;
                        }
                        setState(() {
                          usernameError = null;
                          statusMessage = null;
                          statusOk = false;
                        });
                      },
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).nextFocus(),
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        errorText: usernameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      enabled: !busy,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (passwordError == null && statusMessage == null) {
                          return;
                        }
                        setState(() {
                          passwordError = null;
                          statusMessage = null;
                          statusOk = false;
                        });
                      },
                      onSubmitted: (_) =>
                          unawaited(saveConnection(setState, dialogContext)),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        helperText: savedBasicAuth == null
                            ? null
                            : 'Leave blank to keep existing password',
                        errorText: passwordError,
                        suffixIcon: IconButton(
                          tooltip: obscurePassword ? l10n.show : l10n.hide,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                        ),
                      ),
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          statusMessage!,
                          style: TextStyle(
                            color: statusOk ? scheme.primary : scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () =>
                            unawaited(testConnection(setState, dialogContext)),
                  child: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test connection'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () =>
                            unawaited(saveConnection(setState, dialogContext)),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          MaterialLocalizations.of(
                            dialogContext,
                          ).saveButtonLabel,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    // The dialog route can keep TextField widgets alive during its pop
    // animation; disposing these controllers from the launcher closure can race
    // that animation. A dedicated StatefulWidget can own disposal if this
    // dialog grows further.
  }

  if (saved && context.mounted) {
    context.showSnack(l10n.done);
  }
}

void _logAddRemoteAccountFailure({
  required AccountType accountType,
  required String authMode,
  required String baseUrl,
  String? profileId,
  required Object error,
  required StackTrace stackTrace,
}) {
  AppLogger.w(
    'Add remote account failed',
    tag: 'account',
    error: error,
    stackTrace: stackTrace,
    context: _addRemoteAccountFailureContext(
      accountType: accountType,
      authMode: authMode,
      baseUrl: baseUrl,
      profileId: profileId,
      error: error,
    ),
  );
}

Map<String, Object?> _addRemoteAccountFailureContext({
  required AccountType accountType,
  required String authMode,
  required String baseUrl,
  String? profileId,
  Object? error,
}) {
  final extra = <String, Object?>{
    'operation': 'addRemoteAccount',
    'accountType': accountType.wire,
    'authMode': authMode,
    if (profileId != null && profileId.trim().isNotEmpty)
      'profileId': profileId.trim(),
  };
  final uri = Uri.tryParse(baseUrl.trim());
  final context = uri == null ? extra : logContextForUri(uri, extra: extra);
  if (error is GoogleReaderProbeException) {
    return <String, Object?>{...context, ...error.logContext};
  }
  return context;
}

void _logGoogleReaderAccountConnectionFailure({
  required String operation,
  required String accountId,
  required String? profileId,
  required String baseUrl,
  required Object error,
  required StackTrace stackTrace,
}) {
  AppLogger.w(
    'Google Reader account connection failed',
    tag: 'account',
    error: error,
    stackTrace: stackTrace,
    context: _googleReaderAccountConnectionFailureContext(
      operation: operation,
      accountId: accountId,
      profileId: profileId,
      baseUrl: baseUrl,
      error: error,
    ),
  );
}

Map<String, Object?> _googleReaderAccountConnectionFailureContext({
  required String operation,
  required String accountId,
  required String? profileId,
  required String baseUrl,
  required Object error,
}) {
  final extra = <String, Object?>{
    'operation': operation,
    'accountId': accountId,
    'accountType': AccountType.googleReader.wire,
    'authMode': 'basicAuth',
    if (profileId != null && profileId.trim().isNotEmpty)
      'profileId': profileId.trim(),
  };
  final uri = Uri.tryParse(baseUrl.trim());
  final context = uri == null ? extra : logContextForUri(uri, extra: extra);
  if (error is GoogleReaderProbeException) {
    return <String, Object?>{...context, ...error.logContext};
  }
  return context;
}
