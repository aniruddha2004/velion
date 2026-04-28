import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());

final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getGeminiApiKey();
});

final geminiModelProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.getGeminiModel();
});

final isAIConfiguredProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return service.isAIConfigured();
});

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final SettingsService _service;
  final Ref _ref;

  SettingsNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> setGeminiApiKey(String key) async {
    try {
      await _service.setGeminiApiKey(key);
      _ref.invalidate(geminiApiKeyProvider);
      _ref.invalidate(isAIConfiguredProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setGeminiModel(String model) async {
    try {
      await _service.setGeminiModel(model);
      _ref.invalidate(geminiModelProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setAIProvider(String provider) async {
    try {
      await _service.setAIProvider(provider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service, ref);
});
