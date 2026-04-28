import 'package:hive/hive.dart';

class SettingsService {
  static const _boxName = 'settings';
  static const _apiKeyKey = 'gemini_api_key';
  static const _modelKey = 'gemini_model';
  static const _providerKey = 'ai_provider';

  Box? _box;

  Future<Box> get _settingsBox async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<String?> getGeminiApiKey() async {
    final box = await _settingsBox;
    return box.get(_apiKeyKey) as String?;
  }

  Future<void> setGeminiApiKey(String key) async {
    final box = await _settingsBox;
    await box.put(_apiKeyKey, key);
  }

  Future<String> getGeminiModel() async {
    final box = await _settingsBox;
    return box.get(_modelKey, defaultValue: 'gemini-2.5-flash') as String;
  }

  Future<void> setGeminiModel(String model) async {
    final box = await _settingsBox;
    await box.put(_modelKey, model);
  }

  Future<String> getAIProvider() async {
    final box = await _settingsBox;
    return box.get(_providerKey, defaultValue: 'gemini') as String;
  }

  Future<void> setAIProvider(String provider) async {
    final box = await _settingsBox;
    await box.put(_providerKey, provider);
  }

  Future<bool> isAIConfigured() async {
    final apiKey = await getGeminiApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
}
