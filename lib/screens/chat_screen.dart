import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/news_article.dart';
import '../providers/ai_provider.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final NewsArticle article;

  const ChatScreen({super.key, required this.article});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  String? _sessionId;
  genai.ChatSession? _chatSession;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _endSession();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final isConfigured = await ref.read(settingsServiceProvider).isAIConfigured();
    if (!isConfigured) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'AI not configured. Please set up your Gemini API key in Settings.';
      });
      return;
    }

    // Fetch full article content if not already stored
    String? fullContent = widget.article.fullContent;
    if (fullContent == null || fullContent.isEmpty) {
      final previewService = ref.read(linkPreviewServiceProvider);
      fullContent = await previewService.fetchFullArticleContent(widget.article.url);
      if (fullContent != null) {
        final article = widget.article;
        final updated = article.copyWith(fullContent: fullContent);
        await ref.read(newsRepositoryProvider).updateArticle(updated);
      }
    }

    final geminiService = ref.read(geminiServiceProvider);
    final result = await geminiService.startChatSession(
      articleId: widget.article.id,
      articleTitle: widget.article.displayTitle,
      articleDescription: widget.article.description,
      articleUrl: widget.article.url,
      fullContent: fullContent,
    );

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _isInitializing = false;
        _errorMessage = result.error;
      });
      return;
    }

    setState(() {
      _sessionId = result.sessionId;
      _chatSession = result.chatSession;
      _isInitializing = false;
    });
  }

  Future<void> _endSession() async {
    if (_sessionId != null) {
      final geminiService = ref.read(geminiServiceProvider);
      await geminiService.endChatSession(_sessionId!, widget.article.id);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatSession == null || _sessionId == null) return;

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _errorMessage = null;
    });

    _scrollToBottom();

    final geminiService = ref.read(geminiServiceProvider);
    final response = await geminiService.sendMessage(
      sessionId: _sessionId!,
      articleId: widget.article.id,
      chatSession: _chatSession!,
      message: text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.error != null) {
        _errorMessage = response.error;
      } else if (response.text != null) {
        _messages.add(_ChatMessage(role: 'assistant', content: response.text!));
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D12),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF16181F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chat with AI',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.article.displayTitle,
              style: const TextStyle(color: Color(0xFF5A5A6A), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6878FF)))
          : Column(
              children: [
                // Messages
                Expanded(
                  child: _messages.isEmpty && _errorMessage == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Ask about this article',
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The AI will answer based on the article content',
                                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5A5A6A)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length + (_errorMessage != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _messages.length) {
                              return _buildMessageBubble(_messages[index]);
                            }
                            // Error message
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Loading indicator
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF6878FF).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Thinking...',
                          style: const TextStyle(color: Color(0xFF5A5A6A), fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                // Input
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B0D12),
                    border: Border(top: BorderSide(color: Color(0xFF1E2029), width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Ask about this article...',
                                hintStyle: TextStyle(color: Color(0xFF5A5A6A), fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              onPressed: _isLoading ? null : _sendMessage,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: _isLoading
                                      ? null
                                      : const LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                                  color: _isLoading ? const Color(0xFF1E2029) : null,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: _isLoading ? const Color(0xFF5A5A6A) : Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6878FF).withOpacity(0.15)
                    : const Color(0xFF16181F),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF6878FF).withOpacity(0.3)
                      : const Color(0xFF1E2029),
                  width: 0.5,
                ),
              ),
              child: MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : const Color(0xFFE0E0F0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  h1: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0F0), fontSize: 18, fontWeight: FontWeight.w700),
                  h2: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0F0), fontSize: 16, fontWeight: FontWeight.w700),
                  h3: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0F0), fontSize: 14, fontWeight: FontWeight.w700),
                  listBullet: TextStyle(color: isUser ? Colors.white70 : const Color(0xFF6878FF), fontSize: 14),
                  code: TextStyle(color: const Color(0xFF6878FF), backgroundColor: const Color(0xFF1E2029), fontSize: 12),
                  codeblockDecoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(8)),
                  blockquote: TextStyle(color: isUser ? Colors.white70 : const Color(0xFFA6ADBD), fontSize: 14),
                  blockquoteDecoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(4)),
                  strong: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0F0), fontSize: 14, fontWeight: FontWeight.w700),
                  em: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0F0), fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2029),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Color(0xFF6878FF), size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;

  _ChatMessage({required this.role, required this.content});
}
