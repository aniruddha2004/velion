import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_article.dart';
import '../providers/news_provider.dart';

class ArticleDetailScreen extends ConsumerWidget {
  final NewsArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  Future<void> _openOriginalArticle(BuildContext context) async {
    final uri = Uri.parse(article.url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link'), behavior: SnackBarBehavior.floating),
          );
        }
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
      '${article.displayTitle}\n${article.url}',
      subject: article.displayTitle,
    );
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: article.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy • h:mm a').format(date);
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
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
              isSelected: article.category == 'tech',
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(newsRepositoryProvider).changeCategory(article.id, 'tech');
                _invalidateAll(ref);
              },
            ),
            const SizedBox(height: 10),
            _categoryOption(
              label: 'General',
              icon: Icons.public_outlined,
              gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
              isSelected: article.category == 'general',
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(newsRepositoryProvider).changeCategory(article.id, 'general');
                _invalidateAll(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
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
              await ref.read(newsRepositoryProvider).deleteArticle(article.id);
              _invalidateAll(ref);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article deleted')));
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _invalidateAll(WidgetRef ref) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isTech = article.category == 'tech';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: article.imageUrl != null ? 300 : 0,
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
            flexibleSpace: article.imageUrl != null
                ? FlexibleSpaceBar(
                    background: Container(
                      color: const Color(0xFF16181F),
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: article.imageUrl!, fit: BoxFit.fitWidth,
                          placeholder: (_, __) => Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E2029), Color(0xFF16181F)])),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E2029), Color(0xFF16181F)])),
                            child: const Icon(Icons.image_not_supported, color: Color(0xFF2A2C38)),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Category + Source
                Row(
                  children: [
                    // Category badge
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
                    if (article.faviconUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: article.faviconUrl!, width: 22, height: 22,
                          errorWidget: (_, __, ___) => _sourceIconLarge(),
                        ),
                      )
                    else
                      _sourceIconLarge(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        article.hostName,
                        style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF6878FF), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(article.displayTitle, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.3)),
                if (article.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 20),
                  Text(article.description!, style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFFB0B0D0), height: 1.6)),
                ],
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Category',
                        gradient: const [Color(0xFF6878FF), Color(0xFF3B82F6)],
                        onTap: () => _showCategoryPicker(context, ref),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.archive_outlined,
                        label: 'Archive',
                        gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                        onTap: () async {
                          await ref.read(newsRepositoryProvider).archiveArticle(article.id);
                          _invalidateAll(ref);
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
                        onTap: () => _showDeleteConfirmation(context, ref),
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
                          Text(_formatDate(article.addedAt), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
