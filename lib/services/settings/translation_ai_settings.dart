import '../../utils/language_utils.dart';
import 'settings_json.dart';

class TranslationAiSettings {
  const TranslationAiSettings({
    required this.version,
    required this.translationProvider,
    required this.aiSummaryServiceId,
    required this.targetLanguageTag,
    required this.aiSummaryPrompt,
    required this.aiTranslationPrompt,
    required this.tpmLimit,
    required this.disabledTranslationReminderLanguages,
    required this.aiServices,
    required this.defaultAiServiceId,
    required this.deepL,
    required this.deepLX,
  });

  static const int currentVersion = 2;

  static TranslationAiSettings defaults() {
    return const TranslationAiSettings(
      version: currentVersion,
      translationProvider: TranslationProviderSelection.googleWeb(),
      aiSummaryServiceId: null,
      targetLanguageTag: null,
      aiSummaryPrompt: null,
      aiTranslationPrompt: null,
      tpmLimit: 0,
      disabledTranslationReminderLanguages: <String>[],
      aiServices: <AiServiceConfig>[],
      defaultAiServiceId: null,
      deepL: DeepLSettings(),
      deepLX: DeepLXSettings(),
    );
  }

  final int version;
  final TranslationProviderSelection translationProvider;

  /// The AI service id used for AI summary.
  ///
  /// When `null`, falls back to [defaultAiServiceId].
  final String? aiSummaryServiceId;

  /// Target language for translation/summary.
  ///
  /// - `null` means following the current app/system language.
  /// - Otherwise uses a BCP-47 language tag (e.g. "en", "zh", "zh-Hant").
  final String? targetLanguageTag;

  /// Custom AI summary prompt template. When empty/null, uses built-in defaults.
  final String? aiSummaryPrompt;

  /// Custom AI translation prompt template. Only applies when using AI translation.
  final String? aiTranslationPrompt;

  /// Estimated tokens-per-minute limit for AI/API requests.
  ///
  /// `0` means unlimited.
  final int tpmLimit;

  /// Source language tags that should not show the "language mismatch" reminder.
  final List<String> disabledTranslationReminderLanguages;

  final List<AiServiceConfig> aiServices;
  final String? defaultAiServiceId;
  final DeepLSettings deepL;
  final DeepLXSettings deepLX;

  TranslationAiSettings copyWith({
    int? version,
    TranslationProviderSelection? translationProvider,
    Object? aiSummaryServiceId = _unset,
    Object? targetLanguageTag = _unset,
    Object? aiSummaryPrompt = _unset,
    Object? aiTranslationPrompt = _unset,
    int? tpmLimit,
    List<String>? disabledTranslationReminderLanguages,
    List<AiServiceConfig>? aiServices,
    Object? defaultAiServiceId = _unset,
    DeepLSettings? deepL,
    DeepLXSettings? deepLX,
  }) {
    return TranslationAiSettings(
      version: version ?? this.version,
      translationProvider: translationProvider ?? this.translationProvider,
      aiSummaryServiceId: aiSummaryServiceId == _unset
          ? this.aiSummaryServiceId
          : aiSummaryServiceId as String?,
      targetLanguageTag: targetLanguageTag == _unset
          ? this.targetLanguageTag
          : targetLanguageTag as String?,
      aiSummaryPrompt: aiSummaryPrompt == _unset
          ? this.aiSummaryPrompt
          : aiSummaryPrompt as String?,
      aiTranslationPrompt: aiTranslationPrompt == _unset
          ? this.aiTranslationPrompt
          : aiTranslationPrompt as String?,
      tpmLimit: tpmLimit ?? this.tpmLimit,
      disabledTranslationReminderLanguages:
          disabledTranslationReminderLanguages ??
          this.disabledTranslationReminderLanguages,
      aiServices: aiServices ?? this.aiServices,
      defaultAiServiceId: defaultAiServiceId == _unset
          ? this.defaultAiServiceId
          : defaultAiServiceId as String?,
      deepL: deepL ?? this.deepL,
      deepLX: deepLX ?? this.deepLX,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'translationProvider': translationProvider.toJson(),
    'aiSummaryServiceId': aiSummaryServiceId,
    'targetLanguageTag': targetLanguageTag,
    'aiSummaryPrompt': aiSummaryPrompt,
    'aiTranslationPrompt': aiTranslationPrompt,
    'tpmLimit': tpmLimit,
    'disabledTranslationReminderLanguages':
        disabledTranslationReminderLanguages,
    'aiServices': aiServices.map((s) => s.toJson()).toList(growable: false),
    'defaultAiServiceId': defaultAiServiceId,
    'deepL': deepL.toJson(),
    'deepLX': deepLX.toJson(),
  };

  static TranslationAiSettings fromJson(Map<String, Object?> json) {
    final version = readIntOr(json['version'], currentVersion);

    final translationProvider = TranslationProviderSelection.fromJson(
      json['translationProvider'],
    );

    final aiSummaryServiceId = readOptionalString(json['aiSummaryServiceId']);
    final targetLanguageTag = readOptionalString(json['targetLanguageTag']);
    final aiSummaryPrompt = readOptionalString(json['aiSummaryPrompt']);
    final aiTranslationPrompt = readOptionalString(json['aiTranslationPrompt']);
    final tpmLimit = readIntOr(json['tpmLimit'], 0);

    final disabledTranslationReminderLanguages = <String>[];
    final rawDisabled = json['disabledTranslationReminderLanguages'];
    if (rawDisabled is List) {
      for (final raw in rawDisabled) {
        final s = readStringOrEmpty(raw);
        if (s.isEmpty) continue;
        disabledTranslationReminderLanguages.add(s);
      }
    }

    final rawServices = json['aiServices'];
    final services = <AiServiceConfig>[];
    if (rawServices is List) {
      for (final raw in rawServices) {
        final service = AiServiceConfig.fromJson(raw);
        if (service == null) continue;
        services.add(service);
      }
    }

    final defaultId = readOptionalString(json['defaultAiServiceId']);

    final deepL = DeepLSettings.fromJson(json['deepL']);
    final deepLX = DeepLXSettings.fromJson(json['deepLX']);

    final loaded = TranslationAiSettings(
      version: version,
      translationProvider: translationProvider,
      aiSummaryServiceId: aiSummaryServiceId,
      targetLanguageTag: targetLanguageTag,
      aiSummaryPrompt: aiSummaryPrompt,
      aiTranslationPrompt: aiTranslationPrompt,
      tpmLimit: tpmLimit < 0 ? 0 : tpmLimit,
      disabledTranslationReminderLanguages:
          disabledTranslationReminderLanguages,
      aiServices: services,
      defaultAiServiceId: defaultId,
      deepL: deepL,
      deepLX: deepLX,
    );
    return loaded.normalized();
  }

  TranslationAiSettings normalized() {
    // Remove duplicates and empty ids; preserve order (first wins).
    final seenIds = <String>{};
    final normalizedServices = <AiServiceConfig>[];
    for (final s in aiServices) {
      final id = s.id.trim();
      if (id.isEmpty) continue;
      if (seenIds.contains(id)) continue;
      seenIds.add(id);
      normalizedServices.add(s.copyWith(id: id));
    }

    final enabledIds = <String>{
      for (final s in normalizedServices)
        if (s.enabled) s.id,
    };

    String? normalizedDefaultId = defaultAiServiceId;
    if (normalizedDefaultId != null &&
        !enabledIds.contains(normalizedDefaultId)) {
      normalizedDefaultId = null;
    }

    String? normalizedAiSummaryServiceId = aiSummaryServiceId;
    if (normalizedAiSummaryServiceId != null) {
      final trimmed = normalizedAiSummaryServiceId.trim();
      if (trimmed.isEmpty || !enabledIds.contains(trimmed)) {
        normalizedAiSummaryServiceId = null;
      } else {
        normalizedAiSummaryServiceId = trimmed;
      }
    }

    TranslationProviderSelection normalizedProvider = translationProvider;
    if (normalizedProvider.kind == TranslationProviderKind.aiService) {
      final id = normalizedProvider.aiServiceId;
      if (id == null || id.trim().isEmpty || !enabledIds.contains(id.trim())) {
        normalizedProvider = const TranslationProviderSelection.googleWeb();
      } else {
        normalizedProvider = TranslationProviderSelection.aiService(id.trim());
      }
    }

    final normalizedTargetLang = (() {
      final raw = (targetLanguageTag ?? '').trim();
      if (raw.isEmpty) return '';
      final canonical = canonicalLanguageIdentityTag(raw);
      return canonical == unknownLanguageTag ? '' : canonical;
    })();

    final normalizedDisabledReminderLangs = <String>[];
    final seenLangs = <String>{};
    for (final raw in disabledTranslationReminderLanguages) {
      final canonical = canonicalLanguageIdentityTag(raw);
      final s = canonical == unknownLanguageTag ? '' : canonical;
      if (s.isEmpty) continue;
      if (!seenLangs.add(s)) continue;
      normalizedDisabledReminderLangs.add(s);
    }

    return TranslationAiSettings(
      version: version,
      translationProvider: normalizedProvider,
      aiSummaryServiceId: normalizedAiSummaryServiceId,
      targetLanguageTag: normalizedTargetLang.isEmpty
          ? null
          : normalizedTargetLang,
      aiSummaryPrompt: readOptionalString(aiSummaryPrompt),
      aiTranslationPrompt: readOptionalString(aiTranslationPrompt),
      tpmLimit: tpmLimit < 0 ? 0 : tpmLimit,
      disabledTranslationReminderLanguages: normalizedDisabledReminderLangs,
      aiServices: normalizedServices,
      defaultAiServiceId: normalizedDefaultId,
      deepL: deepL,
      deepLX: deepLX,
    );
  }
}

enum TranslationProviderKind {
  googleWeb,
  bingWeb,
  baiduApi,
  deepLApi,
  deepLX,
  aiService,
}

class TranslationProviderSelection {
  const TranslationProviderSelection({required this.kind, this.aiServiceId});

  const TranslationProviderSelection.googleWeb()
    : kind = TranslationProviderKind.googleWeb,
      aiServiceId = null;

  const TranslationProviderSelection.bingWeb()
    : kind = TranslationProviderKind.bingWeb,
      aiServiceId = null;

  const TranslationProviderSelection.baiduApi()
    : kind = TranslationProviderKind.baiduApi,
      aiServiceId = null;

  const TranslationProviderSelection.deepLApi()
    : kind = TranslationProviderKind.deepLApi,
      aiServiceId = null;

  const TranslationProviderSelection.deepLX()
    : kind = TranslationProviderKind.deepLX,
      aiServiceId = null;

  const TranslationProviderSelection.aiService(String this.aiServiceId)
    : kind = TranslationProviderKind.aiService;

  final TranslationProviderKind kind;
  final String? aiServiceId;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'aiServiceId': aiServiceId,
  };

  static TranslationProviderSelection fromJson(Object? json) {
    if (json is String) {
      final kind = _parseKind(json);
      return TranslationProviderSelection._fromKind(kind, aiServiceId: null);
    }
    if (json is! Map) return const TranslationProviderSelection.googleWeb();
    final map = json.cast<String, Object?>();
    final kind = _parseKind(map['kind']);
    final rawAiId = map['aiServiceId'];
    final aiServiceId = rawAiId is String && rawAiId.trim().isNotEmpty
        ? rawAiId.trim()
        : null;
    return TranslationProviderSelection._fromKind(
      kind,
      aiServiceId: aiServiceId,
    );
  }

  static TranslationProviderKind _parseKind(Object? raw) {
    return readEnumByNameOr(
      TranslationProviderKind.values,
      raw,
      TranslationProviderKind.googleWeb,
    );
  }

  static TranslationProviderSelection _fromKind(
    TranslationProviderKind kind, {
    required String? aiServiceId,
  }) {
    return switch (kind) {
      TranslationProviderKind.googleWeb =>
        const TranslationProviderSelection.googleWeb(),
      TranslationProviderKind.bingWeb =>
        const TranslationProviderSelection.bingWeb(),
      TranslationProviderKind.baiduApi =>
        const TranslationProviderSelection.baiduApi(),
      TranslationProviderKind.deepLApi =>
        const TranslationProviderSelection.deepLApi(),
      TranslationProviderKind.deepLX =>
        const TranslationProviderSelection.deepLX(),
      TranslationProviderKind.aiService =>
        TranslationProviderSelection.aiService(aiServiceId ?? ''),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TranslationProviderSelection &&
            other.kind == kind &&
            other.aiServiceId == aiServiceId;
  }

  @override
  int get hashCode => Object.hash(kind, aiServiceId);
}

enum AiServiceApiType {
  openAiChatCompletions,
  openAiResponses,
  gemini,
  anthropic,
}

class AiServiceConfig {
  const AiServiceConfig({
    required this.id,
    required this.name,
    required this.apiType,
    required this.baseUrl,
    required this.defaultModel,
    required this.enabled,
  });

  final String id;
  final String name;
  final AiServiceApiType apiType;
  final String baseUrl;
  final String defaultModel;
  final bool enabled;

  AiServiceConfig copyWith({
    String? id,
    String? name,
    AiServiceApiType? apiType,
    String? baseUrl,
    String? defaultModel,
    bool? enabled,
  }) {
    return AiServiceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiType: apiType ?? this.apiType,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'apiType': apiType.name,
    'baseUrl': baseUrl,
    'defaultModel': defaultModel,
    'enabled': enabled,
  };

  static AiServiceConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = json.cast<String, Object?>();
    final id = readStringOrEmpty(map['id']);
    if (id.isEmpty) return null;
    final name = readStringOrEmpty(map['name']);
    final apiType = readEnumByNameOr(
      AiServiceApiType.values,
      map['apiType'],
      AiServiceApiType.openAiChatCompletions,
    );

    return AiServiceConfig(
      id: id,
      name: name.isEmpty ? id : name,
      apiType: apiType,
      baseUrl: readStringOrEmpty(map['baseUrl']),
      defaultModel: readStringOrEmpty(map['defaultModel']),
      enabled: readBoolOr(map['enabled'], fallback: true),
    );
  }
}

enum DeepLEndpoint { free, pro }

class DeepLSettings {
  const DeepLSettings({this.endpoint = DeepLEndpoint.free});

  final DeepLEndpoint endpoint;

  Map<String, Object?> toJson() => <String, Object?>{'endpoint': endpoint.name};

  static DeepLSettings fromJson(Object? json) {
    if (json is! Map) return const DeepLSettings();
    final map = json.cast<String, Object?>();
    return DeepLSettings(
      endpoint: readEnumByNameOr(
        DeepLEndpoint.values,
        map['endpoint'],
        DeepLEndpoint.free,
      ),
    );
  }
}

class DeepLXSettings {
  const DeepLXSettings({this.baseUrl = ''});

  final String baseUrl;

  Map<String, Object?> toJson() => <String, Object?>{'baseUrl': baseUrl};

  static DeepLXSettings fromJson(Object? json) {
    if (json is! Map) return const DeepLXSettings();
    final map = json.cast<String, Object?>();
    return DeepLXSettings(baseUrl: readStringOrEmpty(map['baseUrl']));
  }
}

const Object _unset = Object();
