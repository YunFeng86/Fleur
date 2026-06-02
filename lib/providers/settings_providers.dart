import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> setFontSize(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await save(cur.copyWith(fontSize: value));
  }

  Future<void> setLineHeight(double value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await save(cur.copyWith(lineHeight: value));
  }

  Future<void> setFontFamily(ReaderFontFamily value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await save(cur.copyWith(fontFamily: value));
  }

  Future<void> setReaderTheme(ReaderThemePreset value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await save(cur.copyWith(readerTheme: value));
  }

  Future<void> setContentWidthPreset(ReaderContentWidthPreset value) async {
    final cur = state.valueOrNull ?? const ReaderSettings();
    await save(cur.copyWith(contentWidthPreset: value));
  }

  Future<void> resetReaderAppearance() async {
    await save(const ReaderSettings());
  }
}

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettings>(
      ReaderSettingsController.new,
    );
