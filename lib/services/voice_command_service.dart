import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_service.dart';
import 'settings_service.dart';
import 'objectbox_service.dart';

enum VoiceIntentType {
  viewDocument,
  viewNews,
  searchNews,
  unknown,
}

class VoiceIntent {
  final VoiceIntentType type;
  final String target; // document name, search query, etc.
  final String? groupHint; // for documents - which group to look in
  final String rawCommand;
  final double confidence;

  VoiceIntent({
    required this.type,
    required this.target,
    this.groupHint,
    required this.rawCommand,
    required this.confidence,
  });

  factory VoiceIntent.unknown(String rawCommand) {
    return VoiceIntent(
      type: VoiceIntentType.unknown,
      target: '',
      rawCommand: rawCommand,
      confidence: 0.0,
    );
  }
}

class VoiceCommandService {
  final SettingsService _settings;
  final ObjectBoxService _objectBox;

  VoiceCommandService(this._settings, this._objectBox);

  Future<GenerativeModel?> _getModel() async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final modelName = await _settings.getGeminiModel();

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.text(
        'You are Velion\'s voice command parser. Analyze user voice commands and extract intent. '
        'Respond ONLY with valid JSON in this exact format:\n'
        '{\n'
        '  "intent": "viewDocument|viewNews|searchNews|unknown",\n'
        '  "target": "the main subject of the request",\n'
        '  "groupHint": "for documents - which folder/group to look in, or null",\n'
        '  "confidence": 0.95\n'
        '}\n\n'
        'Intent definitions:\n'
        '- viewDocument: User wants to see/view/open a specific document or file\n'
        '- viewNews: User wants to browse/view news articles\n'
        '- searchNews: User wants to search for specific news topics\n'
        '- unknown: Cannot determine what user wants\n\n'
        'Examples:\n'
        '"Show me my Aadhaar card" -> {"intent": "viewDocument", "target": "aadhaar", "groupHint": "aadhaar", "confidence": 0.95}\n'
        '"Show my marksheet" -> {"intent": "viewDocument", "target": "marksheet", "groupHint": "marksheet", "confidence": 0.9}\n'
        '"Show news about Kubernetes" -> {"intent": "searchNews", "target": "kubernetes", "groupHint": null, "confidence": 0.95}\n'
        '"Open my PAN card" -> {"intent": "viewDocument", "target": "pan", "groupHint": "pan", "confidence": 0.9}\n'
        '"Show latest tech news" -> {"intent": "viewNews", "target": "tech", "groupHint": null, "confidence": 0.85}\n'
        '"Find articles about AI" -> {"intent": "searchNews", "target": "AI", "groupHint": null, "confidence": 0.9}',
      ),
    );
  }

  Future<VoiceIntent> parseCommand(String command) async {
    if (command.trim().isEmpty) {
      return VoiceIntent.unknown(command);
    }

    final model = await _getModel();
    if (model == null) {
      // Fallback to simple keyword matching if AI not available
      return _fallbackParse(command);
    }

    try {
      final response = await model.generateContent([Content.text(command)]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return VoiceIntent.unknown(command);
      }

      // Extract JSON from response
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final intentStr = json['intent'] as String? ?? 'unknown';
      final target = json['target'] as String? ?? '';
      final groupHint = json['groupHint'] as String?;
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;

      return VoiceIntent(
        type: _parseIntentType(intentStr),
        target: target.toLowerCase(),
        groupHint: groupHint?.toLowerCase(),
        rawCommand: command,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('Error parsing voice command: $e');
      return _fallbackParse(command);
    }
  }

  VoiceIntent _fallbackParse(String command) {
    final lower = command.toLowerCase();

    // Simple keyword matching fallback
    if (lower.contains('news') || lower.contains('article')) {
      // Extract search term
      final searchTerms = lower
          .replaceAll(RegExp(r'\b(show|me|my|the|latest|about|on|find|search|for|news|articles)\b'), '')
          .trim();

      if (searchTerms.isNotEmpty) {
        return VoiceIntent(
          type: VoiceIntentType.searchNews,
          target: searchTerms,
          rawCommand: command,
          confidence: 0.6,
        );
      }

      return VoiceIntent(
        type: VoiceIntentType.viewNews,
        target: '',
        rawCommand: command,
        confidence: 0.7,
      );
    }

    // Assume document request
    final docTerms = lower
        .replaceAll(RegExp(r'\b(show|me|my|the|open|view|display)\b'), '')
        .trim();

    if (docTerms.isNotEmpty) {
      return VoiceIntent(
        type: VoiceIntentType.viewDocument,
        target: docTerms,
        groupHint: docTerms,
        rawCommand: command,
        confidence: 0.6,
      );
    }

    return VoiceIntent.unknown(command);
  }

  VoiceIntentType _parseIntentType(String intent) {
    switch (intent.toLowerCase()) {
      case 'viewdocument':
        return VoiceIntentType.viewDocument;
      case 'viewnews':
        return VoiceIntentType.viewNews;
      case 'searchnews':
        return VoiceIntentType.searchNews;
      default:
        return VoiceIntentType.unknown;
    }
  }

  String _extractJson(String text) {
    // Find JSON object in text
    final startIdx = text.indexOf('{');
    final endIdx = text.lastIndexOf('}');

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return text.substring(startIdx, endIdx + 1);
    }

    return '{}';
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print('[VoiceCommandService] $message');
}
