import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/doc_document.dart';
import '../models/doc_group.dart';
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

class VoiceDocumentResolution {
  final String? groupId;
  final String? documentId;
  final double confidence;

  const VoiceDocumentResolution({
    required this.groupId,
    required this.documentId,
    required this.confidence,
  });

  bool get hasMatch => groupId != null && groupId!.isNotEmpty;
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
        'You are Velion\'s smart voice command parser. Your job is to understand user intent even with typos, speech errors, or variations. Be intelligent about extracting what the user actually wants.\n\n'
        'Respond ONLY with valid JSON in this exact format:\n'
        '{\n'
        '  "intent": "viewDocument|viewNews|searchNews|unknown",\n'
        '  "target": "the main subject/document/topic name (extract the core noun, ignore filler words)",\n'
        '  "groupHint": "for documents - which folder/group to look in, or null",\n'
        '  "confidence": 0.95\n'
        '}\n\n'
        'CRITICAL RULES:\n'
        '1. Correct common speech-to-text errors: "shop"="show", "wat"="what", "aadhar"="aadhaar"\n'
        '2. Handle synonyms: "get"/"bring"/"load"/"display"/"open"/"view"/"show" all mean the same\n'
        '3. Extract ONLY the core document/topic name - remove action verbs and filler words\n'
        '4. If user mentions a document, intent is "viewDocument" not "searchNews"\n'
        '5. Keep target short and clean - just the key identifier\n'
        '6. For news search, the target must be the actual topic only, never connector/filler words like "to", "about", "related", "regarding", "articles"\n\n'
        'Intent definitions:\n'
        '- viewDocument: User wants to see/open a specific document/file (Aadhaar, PAN, marksheet, passport, certificate, etc.)\n'
        '- viewNews: User wants to browse/view saved news articles\n'
        '- searchNews: User wants to search the web for news on a topic\n'
        '- unknown: Cannot determine what user wants\n\n'
        'EXAMPLES - Handle variations intelligently:\n'
        'DOCUMENT EXAMPLES:\n'
        '"Show me my Aadhaar card" -> {"intent": "viewDocument", "target": "aadhaar", "groupHint": "aadhaar", "confidence": 0.95}\n'
        '"Shop PAN card" -> {"intent": "viewDocument", "target": "pan", "groupHint": "pan", "confidence": 0.85}\n'
        '"Get my marksheet" -> {"intent": "viewDocument", "target": "marksheet", "groupHint": "marksheet", "confidence": 0.9}\n'
        '"Open passport" -> {"intent": "viewDocument", "target": "passport", "groupHint": "passport", "confidence": 0.9}\n'
        '"Display my 10th certificate" -> {"intent": "viewDocument", "target": "10th certificate", "groupHint": "certificate", "confidence": 0.85}\n'
        '"Bring driving license" -> {"intent": "viewDocument", "target": "driving license", "groupHint": "license", "confidence": 0.85}\n'
        '"Load my voter ID" -> {"intent": "viewDocument", "target": "voter id", "groupHint": "voter", "confidence": 0.9}\n\n'
        'NEWS SEARCH EXAMPLES - Remove filler words, keep ONLY the topic:\n'
        '"Show news about Kubernetes" -> {"intent": "searchNews", "target": "kubernetes", "groupHint": null, "confidence": 0.95}\n'
        '"News article related to AI" -> {"intent": "searchNews", "target": "AI", "groupHint": null, "confidence": 0.95}\n'
        '"Articles regarding machine learning" -> {"intent": "searchNews", "target": "machine learning", "groupHint": null, "confidence": 0.9}\n'
        '"Find news concerning climate change" -> {"intent": "searchNews", "target": "climate change", "groupHint": null, "confidence": 0.9}\n'
        '"Show latest tech news" -> {"intent": "viewNews", "target": "tech", "groupHint": null, "confidence": 0.85}\n'
        '"Find articles about AI" -> {"intent": "searchNews", "target": "AI", "groupHint": null, "confidence": 0.9}\n'
        '"News pertaining to blockchain technology" -> {"intent": "searchNews", "target": "blockchain technology", "groupHint": null, "confidence": 0.9}\n'
        '"Tell me regarding latest developments in robotics" -> {"intent": "searchNews", "target": "robotics", "groupHint": null, "confidence": 0.85}',
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
      final intentType = _parseIntentType(intentStr);
      final cleanedTarget = _postProcessTarget(
        intentType: intentType,
        target: target,
        rawCommand: command,
      );

      return VoiceIntent(
        type: intentType,
        target: cleanedTarget,
        groupHint: groupHint?.trim(),
        rawCommand: command,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('Error parsing voice command: $e');
      return _fallbackParse(command);
    }
  }

  Future<VoiceDocumentResolution?> resolveDocumentSelection({
    required VoiceIntent intent,
    required List<DocGroup> groups,
    required Map<String, List<DocDocument>> documentsByGroup,
  }) async {
    if (groups.isEmpty) return null;

    final model = await _getModel();
    if (model != null) {
      try {
        final response = await model.generateContent([
          Content.text(_buildDocumentResolutionPrompt(
            intent: intent,
            groups: groups,
            documentsByGroup: documentsByGroup,
          )),
        ]);

        final text = response.text;
        if (text != null && text.isNotEmpty) {
          final json = jsonDecode(_extractJson(text)) as Map<String, dynamic>;
          final resolved = VoiceDocumentResolution(
            groupId: json['groupId'] as String?,
            documentId: json['documentId'] as String?,
            confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
          );

          if (_isValidResolution(resolved, groups, documentsByGroup) &&
              resolved.confidence >= 0.4) {
            return resolved;
          }
        }
      } catch (e) {
        debugPrint('Error resolving document selection: $e');
      }
    }

    return _fallbackResolveDocumentSelection(
      intent: intent,
      groups: groups,
      documentsByGroup: documentsByGroup,
    );
  }

  VoiceIntent _fallbackParse(String command) {
    final lower = command.toLowerCase();

    // Simple keyword matching fallback with typo/synonym support
    if (lower.contains('news') || lower.contains('article')) {
      // Extract search term - expanded keyword list including connector words
      final searchTerms = lower
          .replaceAll(RegExp(r'\b(show|me|my|the|latest|about|on|find|search|for|news|articles|article|get|load|bring|display|open|view|tell|related|regarding|concerning|pertaining)\b'), '')
          .replaceAll(RegExp(r'\s+'), ' ')  // Clean up multiple spaces
          .trim()
          .replaceAll(RegExp(r'^\s*to\s+|\s+to\s*$'), '')  // Remove standalone "to" at start/end
          .trim();

      if (searchTerms.isNotEmpty) {
        return VoiceIntent(
          type: VoiceIntentType.searchNews,
          target: _postProcessTarget(
            intentType: VoiceIntentType.searchNews,
            target: searchTerms,
            rawCommand: command,
          ),
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

    // Assume document request - smart extraction with typo correction
    String cleaned = lower;
    
    // Common action verbs and their typos/variations
    final actionPatterns = [
      r'\b(please|pls|kindly|can|could|would|you|need|want)\b',
      r'\b(show|shop|shoe|shot)\b',  // "shop" is common STT error for "show"
      r'\b(get|got|git)\b',
      r'\b(open|oppen)\b',
      r'\b(view|few|vue)\b',
      r'\b(display|disply)\b',
      r'\b(bring|brang)\b',
      r'\b(load|lode)\b',
      r'\b(me|my|mine)\b',
      r'\b(the|da|de)\b',
    ];
    
    for (final pattern in actionPatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern), ' ');
    }
    
    // Clean up multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isNotEmpty) {
      return VoiceIntent(
        type: VoiceIntentType.viewDocument,
        target: cleaned,
        groupHint: cleaned,
        rawCommand: command,
        confidence: 0.6,
      );
    }

    return VoiceIntent.unknown(command);
  }

  String _postProcessTarget({
    required VoiceIntentType intentType,
    required String target,
    required String rawCommand,
  }) {
    if (intentType == VoiceIntentType.searchNews) {
      return _cleanNewsSearchTarget(target, rawCommand);
    }

    return target.trim();
  }

  String _cleanNewsSearchTarget(String target, String rawCommand) {
    final cleanedDirect = _stripNewsFillerWords(target);
    if (_looksUsableNewsTopic(cleanedDirect)) {
      return cleanedDirect;
    }

    final raw = rawCommand.trim();
    final extractedFromRaw = _extractTopicFromRawNewsCommand(raw);
    if (_looksUsableNewsTopic(extractedFromRaw)) {
      return extractedFromRaw;
    }

    return cleanedDirect.isNotEmpty ? cleanedDirect : raw;
  }

  String _extractTopicFromRawNewsCommand(String rawCommand) {
    final lower = rawCommand.toLowerCase().trim();

    final anchoredPatterns = [
      RegExp(r'\brelated to\s+(.+)$', caseSensitive: false),
      RegExp(r'\bregarding\s+(.+)$', caseSensitive: false),
      RegExp(r'\bconcerning\s+(.+)$', caseSensitive: false),
      RegExp(r'\bpertaining to\s+(.+)$', caseSensitive: false),
      RegExp(r'\babout\s+(.+)$', caseSensitive: false),
      RegExp(r'\bon\s+(.+)$', caseSensitive: false),
      RegExp(r'\bfor\s+(.+)$', caseSensitive: false),
    ];

    for (final pattern in anchoredPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        return _stripNewsFillerWords(match.group(1) ?? '');
      }
    }

    return _stripNewsFillerWords(lower);
  }

  String _stripNewsFillerWords(String input) {
    return input
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(show|tell|give|find|search|look|bring|get|open|display|view|me|my|the|latest|recent|news|articles|article|stories|story|related|regarding|concerning|pertaining|about|on|for)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'^\s*to\s+|\s+to\s*$'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _looksUsableNewsTopic(String topic) {
    if (topic.trim().isEmpty) return false;

    final normalized = topic.trim().toLowerCase();
    const invalidTopics = {
      'to',
      'about',
      'on',
      'for',
      'related',
      'regarding',
      'concerning',
      'pertaining',
      'article',
      'articles',
      'news',
    };

    return !invalidTopics.contains(normalized);
  }

  VoiceDocumentResolution? _fallbackResolveDocumentSelection({
    required VoiceIntent intent,
    required List<DocGroup> groups,
    required Map<String, List<DocDocument>> documentsByGroup,
  }) {
    final bestGroup = _findBestGroup(groups, intent);
    if (bestGroup == null || bestGroup.$2 < 0.25) {
      return null;
    }

    final documents = documentsByGroup[bestGroup.$1.id] ?? const <DocDocument>[];
    if (documents.isEmpty) {
      return VoiceDocumentResolution(
        groupId: bestGroup.$1.id,
        documentId: null,
        confidence: bestGroup.$2,
      );
    }

    final bestDocument = _findBestDocument(documents, intent);
    if (bestDocument == null) {
      final onlyDocumentId = documents.length == 1 ? documents.first.id : null;
      return VoiceDocumentResolution(
        groupId: bestGroup.$1.id,
        documentId: onlyDocumentId,
        confidence: bestGroup.$2,
      );
    }

    if (bestDocument.$2 < 0.2 && documents.length > 1) {
      return VoiceDocumentResolution(
        groupId: bestGroup.$1.id,
        documentId: null,
        confidence: bestGroup.$2,
      );
    }

    return VoiceDocumentResolution(
      groupId: bestGroup.$1.id,
      documentId: bestDocument.$1.id,
      confidence: (bestGroup.$2 + bestDocument.$2) / 2,
    );
  }

  (DocGroup, double)? _findBestGroup(List<DocGroup> groups, VoiceIntent intent) {
    (DocGroup, double)? best;

    for (final group in groups) {
      final score = _scoreTextCandidate(
        primaryText: group.name,
        secondaryText: group.description,
        intent: intent,
      );

      if (best == null || score > best.$2) {
        best = (group, score);
      }
    }

    return best;
  }

  (DocDocument, double)? _findBestDocument(
    List<DocDocument> documents,
    VoiceIntent intent,
  ) {
    (DocDocument, double)? best;

    for (final document in documents) {
      final score = _scoreTextCandidate(
        primaryText: document.name,
        secondaryText: document.description,
        intent: intent,
      );

      if (best == null || score > best.$2) {
        best = (document, score);
      }
    }

    return best;
  }

  double _scoreTextCandidate({
    required String primaryText,
    required String? secondaryText,
    required VoiceIntent intent,
  }) {
    final primary = _normalizeText(primaryText);
    final secondary = _normalizeText(secondaryText ?? '');
    final target = _normalizeText(intent.target);
    final groupHint = _normalizeText(intent.groupHint ?? '');
    final raw = _normalizeText(intent.rawCommand);

    var score = 0.0;

    if (target.isNotEmpty) {
      if (primary == target) score += 1.0;
      if (primary.contains(target)) score += 0.8;
      if (secondary.contains(target)) score += 0.35;
      score += _tokenOverlapScore(primary, target) * 0.7;
      score += _tokenOverlapScore(secondary, target) * 0.2;
    }

    if (groupHint.isNotEmpty) {
      if (primary == groupHint) score += 0.9;
      if (primary.contains(groupHint)) score += 0.7;
      score += _tokenOverlapScore(primary, groupHint) * 0.6;
    }

    if (raw.isNotEmpty) {
      score += _tokenOverlapScore(primary, raw) * 0.25;
      score += _tokenOverlapScore(secondary, raw) * 0.1;
    }

    return score;
  }

  double _tokenOverlapScore(String left, String right) {
    final leftTokens = _tokenize(left);
    final rightTokens = _tokenize(right);

    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0.0;

    final overlap = leftTokens.where(rightTokens.contains).length;
    return overlap / rightTokens.length;
  }

  Set<String> _tokenize(String input) {
    return _normalizeText(input)
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-:/.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isValidResolution(
    VoiceDocumentResolution resolution,
    List<DocGroup> groups,
    Map<String, List<DocDocument>> documentsByGroup,
  ) {
    if (!resolution.hasMatch) return false;

    final groupExists = groups.any((group) => group.id == resolution.groupId);
    if (!groupExists) return false;

    if (resolution.documentId == null || resolution.documentId!.isEmpty) {
      return true;
    }

    final documents = documentsByGroup[resolution.groupId] ?? const <DocDocument>[];
    return documents.any((document) => document.id == resolution.documentId);
  }

  String _buildDocumentResolutionPrompt({
    required VoiceIntent intent,
    required List<DocGroup> groups,
    required Map<String, List<DocDocument>> documentsByGroup,
  }) {
    final buffer = StringBuffer()
      ..writeln('You are Velion\'s document resolver.')
      ..writeln('Select the best matching group and document for the user request.')
      ..writeln('Understand paraphrases, multilingual requests, speech-to-text mistakes, abbreviations, and synonyms.')
      ..writeln('Never choose arbitrarily. If nothing matches, return null ids.')
      ..writeln('Respond ONLY as JSON in this exact format:')
      ..writeln('{"groupId":"... or null","documentId":"... or null","confidence":0.92}')
      ..writeln()
      ..writeln('USER COMMAND: ${intent.rawCommand}')
      ..writeln('PARSED TARGET: ${intent.target}')
      ..writeln('PARSED GROUP HINT: ${intent.groupHint ?? 'null'}')
      ..writeln()
      ..writeln('AVAILABLE GROUPS AND DOCUMENTS:');

    for (final group in groups) {
      buffer.writeln(
        '- GROUP id=${group.id}; name=${group.name}; description=${group.description ?? ''}',
      );
      final documents = documentsByGroup[group.id] ?? const <DocDocument>[];
      for (final document in documents) {
        buffer.writeln(
          '  - DOC id=${document.id}; name=${document.name}; description=${document.description ?? ''}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('RULES:')
      ..writeln('1. Match semantically, not only exact words.')
      ..writeln('2. Handle requests like PAN card, permanent account number, tax card as potentially same intent if supported by candidates.')
      ..writeln('3. Prefer the best specific document if available; otherwise choose the best group.')
      ..writeln('4. If a group has exactly one obvious document, it is acceptable to select that document.')
      ..writeln('5. If uncertain, return null ids rather than a random guess.');

    return buffer.toString();
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
