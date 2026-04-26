import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../widgets/link_preview_card.dart';
import 'add_article_screen.dart';
import 'article_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Today', 'This Week'];

  Future<void> _refreshArticles() async {
    ref.invalidate(articlesProvider);
    ref.invalidate(unreadCountProvider);
  }

  List<dynamic> _applyFilter(List<dynamic> articles) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Unread':
        return articles.where((a) => !a.isRead).toList();
      case 'Today':
        return articles.where((a) =>
          a.addedAt.year == now.year &&
          a.addedAt.month == now.month &&
          a.addedAt.day == now.day
        ).toList();
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return articles.where((a) => a.addedAt.isAfter(weekAgo)).toList();
      default:
        return articles;
    }
  }

  void _showDeleteConfirmation(dynamic article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Article', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this article?',
          style: TextStyle(color: Color(0xFF9E9EBF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(newsRepositoryProvider).deleteArticle(article.id);
              ref.invalidate(articlesProvider);
              ref.invalidate(unreadCountProvider);
              ref.invalidate(articleCountProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Article deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(articlesProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'News Feed',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your saved articles and stories',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A7A9A),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = filter == _selectedFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                                  )
                                : null,
                            color: isSelected ? null : const Color(0xFF252540),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF9E9EBF),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Articles list
            articlesAsync.when(
              data: (articles) {
                final filtered = _applyFilter(articles);
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 72,
                            color: const Color(0xFF3D3D5C),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            articles.isEmpty ? 'No articles yet' : 'No matching articles',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF5A5A7A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            articles.isEmpty
                                ? 'Share a link from any app or tap the + button'
                                : 'Try a different filter',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF3D3D5C),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final article = filtered[index];
                      return LinkPreviewCard(
                        article: article,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArticleDetailScreen(article: article),
                          ),
                        ),
                        onLongPress: () => _showDeleteConfirmation(article),
                      );
                    },
                    childCount: filtered.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF5252)),
                      const SizedBox(height: 16),
                      Text('Failed to load articles', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _refreshArticles,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddArticleScreen(),
            ),
          );
          if (result == true) {
            _refreshArticles();
          }
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
