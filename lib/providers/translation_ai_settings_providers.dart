import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/app_logger.dart';
import '../services/settings/translation_ai_secret_store.dart';
import '../services/settings/translation_ai_settings.dart';
import '../services/settings/translation_ai_settings_store.dart';
import '../utils/language_utils.dart';

final translationAiSettingsStoreProvider = Provider<TranslationAiSettingsStore>(
  (ref) => TranslationAiSettingsStore(),
);

final translationAiSecretStoreProvider = Provider<TranslationAiSecretStore>(
  (ref) => TranslationAiSecretStore(),
);

class TranslationAiSettingsController
    extends AsyncNotifier<TranslationAiSettings> {
  @override
  Future<TranslationAiSettings> build() async {
    return ref.read(translationAiSettingsStoreProvider).load();
  }

  Future<void> save(TranslationAiSettings next) async {
    final normalized = next.normalized();
    state = AsyncValue.data(normalized);
    await ref.read(translationAiSettingsStoreProvider).save(normalized);
  }

  Future<void> setTranslationProvider(
    TranslationProviderSelection selection,
  ) async {
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(cur.copyWith(translationProvider: selection));
  }

  Future<void> setTargetLanguageTag(String? languageTag) async {
    final trimmed = (languageTag ?? '').trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(
      cur.copyWith(targetLanguageTag: trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<void> setAiSummaryPrompt(String? prompt) async {
    final trimmed = (prompt ?? '').trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(cur.copyWith(aiSummaryPrompt: trimmed.isEmpty ? null : trimmed));
  }

  Future<void> setAiTranslationPrompt(String? prompt) async {
    final trimmed = (prompt ?? '').trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(
      cur.copyWith(aiTranslationPrompt: trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<void> setTpmLimit(int tpmLimit) async {
    final next = tpmLimit < 0 ? 0 : tpmLimit;
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(cur.copyWith(tpmLimit: next));
  }

  Future<void> disableTranslationReminderForLanguage(String languageTag) async {
    final trimmed = canonicalKnownLanguageTagOrNull(languageTag)?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    if (cur.disabledTranslationReminderLanguages.contains(trimmed)) return;
    await save(
      cur.copyWith(
        disabledTranslationReminderLanguages: [
          ...cur.disabledTranslationReminderLanguages,
          trimmed,
        ],
      ),
    );
  }

  Future<void> enableTranslationReminderForLanguage(String languageTag) async {
    final trimmed = canonicalKnownLanguageTagOrNull(languageTag)?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    final next = cur.disabledTranslationReminderLanguages
        .where((v) => v.trim() != trimmed)
        .toList(growable: false);
    if (next.length == cur.disabledTranslationReminderLanguages.length) return;
    await save(cur.copyWith(disabledTranslationReminderLanguages: next));
  }

  Future<void> setDeepLEndpoint(DeepLEndpoint endpoint) async {
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(cur.copyWith(deepL: DeepLSettings(endpoint: endpoint)));
  }

  Future<void> setDeepLXBaseUrl(String baseUrl) async {
    final trimmed = baseUrl.trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(cur.copyWith(deepLX: DeepLXSettings(baseUrl: trimmed)));
  }

  Future<void> setDefaultAiServiceId(String? serviceId) async {
    final trimmed = (serviceId ?? '').trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(
      cur.copyWith(defaultAiServiceId: trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<void> setAiSummaryServiceId(String? serviceId) async {
    final trimmed = (serviceId ?? '').trim();
    final cur = state.valueOrNull ?? TranslationAiSettings.defaults();
    await save(
      cur.copyWith(aiSummaryServiceId: trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<String> addAiService({
    required String name,
    required AiServiceApiType apiType,
    required String baseUrl,
    required String defaultModel,
    required bool enabled,
    String? apiKey,
  }) async {
    final cur = state.valueOrNull ?? await future;
    final id = _newServiceId();
    final service = AiServiceConfig(
      id: id,
      name: name.trim().isEmpty ? id : name.trim(),
      apiType: apiType,
      baseUrl: baseUrl.trim(),
      defaultModel: defaultModel.trim(),
      enabled: enabled,
    );

    final next = cur.copyWith(aiServices: [...cur.aiServices, service]);
    final trimmedKey = (apiKey ?? '').trim();
    if (trimmedKey.isNotEmpty) {
      final secrets = ref.read(translationAiSecretStoreProvider);
      await secrets.setAiServiceApiKey(id, trimmedKey);
      try {
        await save(next);
      } catch (e, st) {
        _logAiSettingsFailure(
          operation: 'addAiService',
          serviceId: service.id,
          apiType: service.apiType,
          enabled: service.enabled,
          error: e,
          stackTrace: st,
        );
        try {
          await secrets.deleteAiServiceApiKey(id);
        } catch (_) {
          // ignore: best-effort rollback
        }
        state = AsyncValue.data(cur);
        rethrow;
      }
    } else {
      await save(next);
    }

    return id;
  }

  Future<void> updateAiService(
    AiServiceConfig service, {
    String? apiKey,
    String? previousApiKey,
  }) async {
    final cur = state.valueOrNull ?? await future;
    final idx = cur.aiServices.indexWhere((s) => s.id == service.id);
    if (idx < 0) return;

    final nextServices = [...cur.aiServices];
    nextServices[idx] = service;

    if (apiKey != null) {
      final secrets = ref.read(translationAiSecretStoreProvider);
      final trimmedKey = apiKey.trim();
      final nextKey = trimmedKey.isEmpty ? null : trimmedKey;

      final trimmedPrevKey = (previousApiKey ?? '').trim();
      final prevKey = previousApiKey == null
          ? await secrets.getAiServiceApiKey(service.id)
          : (trimmedPrevKey.isEmpty ? null : trimmedPrevKey);

      if (prevKey != nextKey) {
        if (nextKey == null) {
          await secrets.deleteAiServiceApiKey(service.id);
        } else {
          await secrets.setAiServiceApiKey(service.id, nextKey);
        }
      }

      try {
        await save(cur.copyWith(aiServices: nextServices));
      } catch (e, st) {
        _logAiSettingsFailure(
          operation: 'updateAiService',
          serviceId: service.id,
          apiType: service.apiType,
          enabled: service.enabled,
          error: e,
          stackTrace: st,
        );
        if (prevKey != nextKey) {
          try {
            if (prevKey == null) {
              await secrets.deleteAiServiceApiKey(service.id);
            } else {
              await secrets.setAiServiceApiKey(service.id, prevKey);
            }
          } catch (_) {
            // ignore: best-effort rollback
          }
        }
        state = AsyncValue.data(cur);
        rethrow;
      }
    } else {
      await save(cur.copyWith(aiServices: nextServices));
    }
  }

  Future<void> setAiServiceEnabled(String serviceId, bool enabled) async {
    final cur = state.valueOrNull ?? await future;
    final idx = cur.aiServices.indexWhere((s) => s.id == serviceId);
    if (idx < 0) return;

    final nextServices = [...cur.aiServices];
    nextServices[idx] = nextServices[idx].copyWith(enabled: enabled);

    String? nextDefaultId = cur.defaultAiServiceId;
    if (!enabled && nextDefaultId == serviceId) {
      nextDefaultId = null;
      for (final s in nextServices) {
        if (s.enabled) {
          nextDefaultId = s.id;
          break;
        }
      }
    }

    String? nextSummaryServiceId = cur.aiSummaryServiceId;
    if (!enabled && nextSummaryServiceId == serviceId) {
      nextSummaryServiceId = null;
    }

    var nextProvider = cur.translationProvider;
    if (!enabled &&
        nextProvider.kind == TranslationProviderKind.aiService &&
        nextProvider.aiServiceId == serviceId) {
      nextProvider = const TranslationProviderSelection.googleWeb();
    }

    await save(
      cur.copyWith(
        aiServices: nextServices,
        defaultAiServiceId: nextDefaultId,
        aiSummaryServiceId: nextSummaryServiceId,
        translationProvider: nextProvider,
      ),
    );
  }

  Future<void> setDefaultAiService(String serviceId) async {
    final cur = state.valueOrNull ?? await future;
    final idx = cur.aiServices.indexWhere((s) => s.id == serviceId);
    if (idx < 0) return;

    final nextServices = [...cur.aiServices];
    final target = nextServices[idx];
    if (!target.enabled) {
      nextServices[idx] = target.copyWith(enabled: true);
    }

    await save(
      cur.copyWith(aiServices: nextServices, defaultAiServiceId: serviceId),
    );
  }

  Future<void> deleteAiService(String serviceId) async {
    final cur = state.valueOrNull ?? await future;
    final exists = cur.aiServices.any((s) => s.id == serviceId);
    if (!exists) return;

    final remaining = cur.aiServices.where((s) => s.id != serviceId).toList();

    String? nextDefaultId = cur.defaultAiServiceId;
    if (nextDefaultId == serviceId) {
      nextDefaultId = null;
      for (final s in remaining) {
        if (s.enabled) {
          nextDefaultId = s.id;
          break;
        }
      }
    }

    String? nextSummaryServiceId = cur.aiSummaryServiceId;
    if (nextSummaryServiceId == serviceId) {
      nextSummaryServiceId = null;
    }

    var nextProvider = cur.translationProvider;
    if (nextProvider.kind == TranslationProviderKind.aiService &&
        nextProvider.aiServiceId == serviceId) {
      nextProvider = const TranslationProviderSelection.googleWeb();
    }

    await save(
      cur.copyWith(
        aiServices: remaining,
        defaultAiServiceId: nextDefaultId,
        aiSummaryServiceId: nextSummaryServiceId,
        translationProvider: nextProvider,
      ),
    );

    await ref
        .read(translationAiSecretStoreProvider)
        .deleteAiServiceApiKey(serviceId);
  }

  String _newServiceId() {
    // Short, URL-safe-ish id for storage keys.
    const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buf.write(alphabet[rnd.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  static void _logAiSettingsFailure({
    required String operation,
    required String serviceId,
    required AiServiceApiType apiType,
    required bool enabled,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.w(
      'AI service settings save failed',
      tag: 'ai_settings',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'serviceId': serviceId,
        'apiType': apiType.name,
        'enabled': enabled,
      },
    );
  }
}

final translationAiSettingsProvider =
    AsyncNotifierProvider<
      TranslationAiSettingsController,
      TranslationAiSettings
    >(TranslationAiSettingsController.new);
