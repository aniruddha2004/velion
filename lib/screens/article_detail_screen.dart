import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/news_article.dart';
import '../providers/news_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/settings_provider.dart';
import 'chat_screen.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  final NewsArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  ConsumerState<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  String? _aiSummary;
  bool _isLoadingSummary = false;
  bool _summaryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    // Check if summary already exists
    if (widget.article.aiSummary != null && widget.article.aiSummary!.isNotEmpty) {
      setState(() {
        _aiSummary = widget.article.aiSummary;
        _isLoadingSummary = false;
        _summaryLoaded = true;
      });
      return;
    }

    final isConfigured = await ref.read(settingsServiceProvider).isAIConfigured();
    if (!isConfigured) return;

    setState(() => _isLoadingSummary = true);
    final geminiService = ref.read(geminiServiceProvider);

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

    final summary = await geminiService.summarizeArticle(
      title: widget.article.displayTitle,
      description: widget.article.description,
      url: widget.article.url,
      fullContent: fullContent,
    );
    
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _isLoadingSummary = false;
        _summaryLoaded = true;
      });
      
      // Save summary to article
      if (summary != null && summary.isNotEmpty) {
        final article = widget.article;
        final updated = article.copyWith(aiSummary: summary);
        await ref.read(newsRepositoryProvider).updateArticle(updated);
      }
    }
  }

  Future<void> _openOriginalArticle(BuildContext context) async {
    final uri = Uri.parse(widget.article.url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _shareLink(BuildContext context) {
    Share.share(
      '${widget.article.displayTitle}\n${widget.article.url}',
      subject: widget.article.displayTitle,
    );
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.article.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy • h:mm a').format(date);
  }

  void _showCategoryPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Category', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _categoryOption(
              label: 'Tech',
              icon: Icons.computer_outlined,
              gradient: const [Color(0xFF6878FF), Color(0xFF3B82F6)],
              isSelected: widget.article.category == 'tech',
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(newsRepositoryProvider).changeCategory(widget.article.id, 'tech');
                _invalidateAll();
              },
            ),
            const SizedBox(height: 10),
            _categoryOption(
              label: 'General',
              icon: Icons.public_outlined,
              gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
              isSelected: widget.article.category == 'general',
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(newsRepositoryProvider).changeCategory(widget.article.id, 'general');
                _invalidateAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Article', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently remove the article. Are you sure?', style: TextStyle(color: Color(0xFFA6ADBD))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await ref.read(newsRepositoryProvider).deleteArticle(widget.article.id);
              _invalidateAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article deleted')));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _invalidateAll() {
    ref.invalidate(articlesProvider);
    ref.invalidate(archivedArticlesProvider);
    ref.invalidate(techArticlesProvider);
    ref.invalidate(generalArticlesProvider);
    ref.invalidate(unreadArticlesProvider);
    ref.invalidate(articleCountProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(techCountProvider);
    ref.invalidate(generalCountProvider);
    ref.invalidate(archivedCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTech = widget.article.category == 'tech';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: widget.article.imageUrl != null ? 200 : kToolbarHeight,
            collapsedHeight: kToolbarHeight,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0B0D12),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF16181F).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16181F).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: () => _shareLink(context),
                ),
              ),
            ],
            flexibleSpace: widget.article.imageUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: widget.article.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E2029), Color(0xFF16181F)],
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E2029), Color(0xFF16181F)],
                          ),
                        ),
                        child: const Icon(Icons.image_not_supported, color: Color(0xFF2A2C38)),
                      ),
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Category + Source
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isTech ? const [Color(0xFF6878FF), Color(0xFF3B82F6)] : const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isTech ? Icons.computer_outlined : Icons.public_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(isTech ? 'TECH' : 'GENERAL', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.article.faviconUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: widget.article.faviconUrl!, width: 22, height: 22,
                          errorWidget: (_, __, ___) => _sourceIconLarge(),
                        ),
                      )
                    else
                      _sourceIconLarge(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.article.hostName,
                        style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF6878FF), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(widget.article.displayTitle, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.3)),
                if (widget.article.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 20),
                  Text(widget.article.description!, style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFFB0B0D0), height: 1.6)),
                ],

                // Velion's Summary section
                if (_isLoadingSummary) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16181F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        const Text('Generating Velion\'s summary...', style: TextStyle(color: Color(0xFFA6ADBD), fontSize: 13)),
                        const SizedBox(width: 12),
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6878FF))),
                      ],
                    ),
                  ),
                ] else if (_aiSummary != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16181F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6878FF).withOpacity(0.2), width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text('Velion\'s Summary', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF6878FF), fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        MarkdownBody(
                          data: _aiSummary!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFE0E0F0), height: 1.6),
                            h1: theme.textTheme.titleLarge?.copyWith(color: const Color(0xFFE0E0F0), fontWeight: FontWeight.w700),
                            h2: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFFE0E0F0), fontWeight: FontWeight.w700),
                            h3: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFFE0E0F0), fontWeight: FontWeight.w700),
                            listBullet: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF6878FF)),
                            code: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF6878FF), backgroundColor: const Color(0xFF1E2029)),
                            codeblockDecoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(8)),
                            blockquote: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFA6ADBD)),
                            blockquoteDecoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(4)),
                            strong: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFE0E0F0), fontWeight: FontWeight.w700),
                            em: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFE0E0F0), fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_summaryLoaded && _aiSummary == null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16181F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: const Color(0xFF5A5A6A), size: 18),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Could not generate summary. Check your API key in Settings.', style: TextStyle(color: const Color(0xFF5A5A6A), fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        gradient: const [Color(0xFF6878FF), Color(0xFF3B82F6)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ChatScreen(article: widget.article)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Category',
                        gradient: const [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
                        onTap: () => _showCategoryPicker(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.archive_outlined,
                        label: 'Archive',
                        gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                        onTap: () async {
                          await ref.read(newsRepositoryProvider).archiveArticle(widget.article.id);
                          _invalidateAll();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article archived')));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        gradient: const [Color(0xFFFF5252), Color(0xFFFF7043)],
                        onTap: () => _showDeleteConfirmation(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Date card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saved on', style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFFA6ADBD))),
                          const SizedBox(height: 2),
                          Text(_formatDate(widget.article.addedAt), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Open button
                Container(
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF6878FF).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openOriginalArticle(context),
                      borderRadius: BorderRadius.circular(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Open Original Article', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyLink(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA6ADBD),
                      side: const BorderSide(color: Color(0xFF1E2029)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String label, required List<Color> gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: gradient[0].withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gradient[0].withOpacity(0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: gradient[0], fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _categoryOption({required String label, required IconData icon, required List<Color> gradient, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? gradient[0].withOpacity(0.15) : const Color(0xFF1E2029),
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: gradient[0], width: 1.5) : Border.all(color: const Color(0xFF2A2C38), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFFA6ADBD), fontWeight: FontWeight.w600, fontSize: 15))),
            if (isSelected) Icon(Icons.check_circle, color: gradient[0], size: 22),
          ],
        ),
      ),
    );
  }

  Widget _sourceIconLarge() {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: const Icon(Icons.language, size: 14, color: Colors.white),
    );
  }
}
