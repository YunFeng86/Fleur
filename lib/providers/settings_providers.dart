import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/app_logger.dart';
import '../services/settings/reader_settings.dart';
import '../services/settings/reader_settings_store.dart';

final readerSettingsStoreProvider = Provider<ReaderSettingsStore>(
  (ref) => ReaderSettingsStore(),
);

class ReaderSettingsController extends AsyncNotifier<ReaderSettings> {
  @override
  Future<ReaderSettings> build() async {
    return ref.read(readerSettingsStoreProvider).load();
  }

  Future<void> save(ReaderSettings next) async {
    state = AsyncValue.data(next);
    await ref.read(readerSettingsStoreProvider).save(next);
  }

  /// Setter entry point: UI callbacks usually fire this without awaiting, so
  /// persist failures are logged and the optimistic in-memory state is kept
  /// instead of surfacing as an unhandled async exception.
  Future<void> _saveQuietly(ReaderSettings next) async {
    try {
      await save(next);
    } catch (e, s) {
      AppLogger.w(
        'Settings save failed; keeping in-memory state',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'store': 'ReaderSettingsStore'},
      );
    }
  }

  Future<void> setFontSize(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(fontSize: value));
  }

  Future<void> setMinimumFontSize(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(minimumFontSize: value));
  }

  Future<void> setLineHeight(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(lineHeight: value));
  }

  Future<void> setFontFamily(ReaderFontFamily value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(fontFamily: value));
  }

  Future<void> setReaderFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(readerFontStack: value));
  }

  Future<void> setStandardFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(standardFontStack: value));
  }

  Future<void> setSerifFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(serifFontStack: value));
  }

  Future<void> setSansFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(sansFontStack: value));
  }

  Future<void> setMonoFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(monoFontStack: value));
  }

  Future<void> setMathFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(mathFontStack: value));
  }

  Future<void> setReaderTheme(ReaderThemePreset value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(readerTheme: value));
  }

  Future<void> setContentWidthPreset(ReaderContentWidthPreset value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(contentWidthPreset: value));
  }

  Future<void> setCodeFontFamily(CodeFontFamilyPreset value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeFontFamily: value));
  }

  Future<void> setCodeFontStack(String value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeFontStack: value));
  }

  Future<void> setCodeFontSizeMode(CodeFontSizeMode value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeFontSizeMode: value));
  }

  Future<void> setCodeFontSize(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeFontSize: value));
  }

  Future<void> setCodeLineHeight(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeLineHeight: value));
  }

  Future<void> setCodeSoftWrap(bool value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(cur.copyWith(codeSoftWrap: value));
  }

  Future<void> resetReaderAppearance() async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(
      cur.copyWith(
        fontSize: ReaderSettings.defaultFontSize,
        minimumFontSize: ReaderSettings.defaultMinimumFontSize,
        lineHeight: ReaderSettings.defaultLineHeight,
        horizontalPadding: ReaderSettings.defaultHorizontalPadding,
        readerTheme: ReaderThemePreset.defaultLightAware,
        fontFamily: ReaderFontFamily.serif,
        readerFontStack: '',
        standardFontStack: '',
        serifFontStack: '',
        sansFontStack: '',
        monoFontStack: '',
        mathFontStack: '',
        contentWidthPreset: ReaderContentWidthPreset.standard,
        codeFontFamily: CodeFontFamilyPreset.systemMono,
        codeFontStack: '',
        codeFontSizeMode: CodeFontSizeMode.oneStepDown,
        codeFontSize: ReaderSettings.defaultCodeFontSize,
        codeLineHeight: ReaderSettings.defaultCodeLineHeight,
        codeSoftWrap: false,
      ),
    );
  }

  Future<void> resetCodeAppearance() async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await _saveQuietly(
      cur.copyWith(
        codeFontFamily: CodeFontFamilyPreset.systemMono,
        codeFontStack: '',
        codeFontSizeMode: CodeFontSizeMode.oneStepDown,
        codeFontSize: ReaderSettings.defaultCodeFontSize,
        codeLineHeight: ReaderSettings.defaultCodeLineHeight,
        codeSoftWrap: false,
      ),
    );
  }
}

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettings>(
      ReaderSettingsController.new,
    );
