import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'settings_service.dart';
import 'objectbox_service.dart';
import '../models/objectbox_entities.dart';

class GeminiService {
  final SettingsService _settings;
  final ObjectBoxService _objectBox;
  final _uuid = const Uuid();

  GeminiService(this._settings, this._objectBox);

  Future<GenerativeModel?> _getModel({String? systemInstruction}) async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final modelName = await _settings.getGeminiModel();

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: systemInstruction != null
          ? Content.text(systemInstruction)
          : null,
    );
  }

  /// Generate a summary for an article
  Future<String?> summarizeArticle({
    required String title,
    String? description,
    String? url,
    String? fullContent,
  }) async {
    final model = await _getModel(
      systemInstruction: 'You are Velion, a helpful news assistant. Provide a clear, informative summary of the article. '
          'Structure it as:\n'
          '• Brief headline capturing the main point\n'
          '• 2-3 key bullet points\n'
          '• One short paragraph (2-3 sentences) explaining significance\n'
          'Keep it concise but informative. Around 100-150 words total.',
    );
    if (model == null) return null;

    try {
      final prompt = StringBuffer();
      prompt.writeln('Summarize this news article:');
      prompt.writeln('Title: $title');
      if (fullContent != null && fullContent.isNotEmpty) {
        prompt.writeln('\nFull Article Content:\n$fullContent');
      } else {
        if (description != null && description.isNotEmpty) {
          prompt.writeln('Description: $description');
        }
      }
      if (url != null) {
        prompt.writeln('Source: $url');
      }

      final response = await model.generateContent([Content.text(prompt.toString())]);
      return response.text;
    } catch (e) {
      return null;
    }
  }

  /// Start a chat session for a specific article
  Future<ChatSessionResult> startChatSession({
    required String articleId,
    required String articleTitle,
    String? articleDescription,
    String? articleUrl,
    String? fullContent,
  }) async {
    final sessionId = _uuid.v4();

    // Build article context - prefer full content, fallback to description
    final articleContext = StringBuffer();
    articleContext.writeln('Article Title: $articleTitle');
    if (fullContent != null && fullContent.isNotEmpty) {
      articleContext.writeln('\nFull Article Content:\n$fullContent');
    } else if (articleDescription != null && articleDescription.isNotEmpty) {
      articleContext.writeln('Article Description: $articleDescription');
    }
    if (articleUrl != null) {
      articleContext.writeln('Article URL: $articleUrl');
    }

    final contextPrompt = 'You are an AI assistant that answers questions about a '
        'specific news article. Only answer based on the article content provided. '
        'If the user asks about something not related to the article, politely redirect '
        'them to ask about the article.\n\n'
        '${articleContext.toString()}'
        '\nAnswer the user\'s questions with reference to this article.';

    final model = await _getModel(systemInstruction: contextPrompt);
    if (model == null) {
      return ChatSessionResult(error: 'AI not configured. Please set up your API key in Settings.');
    }

    // Store article content in ObjectBox for this session
    final embedding = ArticleEmbedding(
      articleId: articleId,
      content: fullContent ?? '$articleTitle\n${articleDescription ?? ''}',
    );
    await _objectBox.saveArticleEmbedding(embedding);

    // Load any existing messages for this session (fresh session = empty)
    final history = await _objectBox.getSessionMessages(sessionId);
    final chatHistory = history.map((m) => Content(
      m.role == 'user' ? 'user' : 'model',
      [TextPart(m.content)],
    )).toList();

    final chatSession = model.startChat(history: chatHistory.isNotEmpty ? chatHistory : null);

    return ChatSessionResult(
      sessionId: sessionId,
      chatSession: chatSession,
    );
  }

  /// Send a message in an existing chat session
  Future<ChatResponse> sendMessage({
    required String sessionId,
    required String articleId,
    required ChatSession chatSession,
    required String message,
  }) async {
    // Save user message to ObjectBox
    await _objectBox.saveMessage(ChatMessageEntity(
      sessionId: sessionId,
      articleId: articleId,
      role: 'user',
      content: message,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    try {
      final response = await chatSession.sendMessage(Content.text(message));
      final responseText = response.text ?? 'No response generated.';

      // Save assistant message to ObjectBox
      await _objectBox.saveMessage(ChatMessageEntity(
        sessionId: sessionId,
        articleId: articleId,
        role: 'assistant',
        content: responseText,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      return ChatResponse(text: responseText);
    } catch (e) {
      return ChatResponse(error: 'Failed to get response: $e');
    }
  }

  /// End a chat session - clear all session data from ObjectBox
  Future<void> endChatSession(String sessionId, String articleId) async {
    await _objectBox.clearSession(sessionId);
    await _objectBox.deleteArticleEmbedding(articleId);
  }
}

class ChatSessionResult {
  final String? sessionId;
  final ChatSession? chatSession;
  final String? error;

  ChatSessionResult({this.sessionId, this.chatSession, this.error});
}

class ChatResponse {
  final String? text;
  final String? error;

  ChatResponse({this.text, this.error});
}
