import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/objectbox_service.dart';
import '../services/gemini_service.dart';
import 'settings_provider.dart';

final objectBoxServiceProvider = Provider((ref) => ObjectBoxService());

final geminiServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final objectBox = ref.watch(objectBoxServiceProvider);
  return GeminiService(settings, objectBox);
});
