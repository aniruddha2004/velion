import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/news_article.dart';
import '../../providers/news_provider.dart';
import '../../widgets/link_preview_card.dart';
import '../add_article_screen.dart';
import '../article_detail_screen.dart';

class NewsHomeScreen extends ConsumerStatefulWidget {
  const NewsHomeScreen({super.key});

  @override
  ConsumerState<NewsHomeScreen> createState() => _NewsHomeScreenState();
}

class _NewsHomeScreenState extends ConsumerState<NewsHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

  void _showDeleteConfirmation(NewsArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Article', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently remove the article. Are you sure?',
          style: TextStyle(color: Color(0xFFA6ADBD)),
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
              _invalidateAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Article deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(NewsArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                Navigator.pop(context);
                await ref.read(newsRepositoryProvider).changeCategory(article.id, 'tech');
                _invalidateAll();
              },
            ),
            const SizedBox(height: 10),
            _categoryOption(
              label: 'General',
              icon: Icons.public_outlined,
              gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
              isSelected: article.category == 'general',
              onTap: () async {
                Navigator.pop(context);
                await ref.read(newsRepositoryProvider).changeCategory(article.id, 'general');
                _invalidateAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryOption({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? gradient[0].withOpacity(0.15) : const Color(0xFF1E2029),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: gradient[0], width: 1.5)
              : Border.all(color: const Color(0xFF2A2C38), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA6ADBD),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: gradient[0], size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('News Feed', style: theme.textTheme.headlineLarge),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your saved articles and stories',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFA6ADBD),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Category tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF16181F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelPadding: EdgeInsets.zero,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6878FF), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  tabAlignment: TabAlignment.fill,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFFA6ADBD),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.0),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, height: 1.0),
                  tabs: [
                    Tab(height: 44, child: Center(child: Text('All'))),
                    Tab(height: 44, child: Center(child: Text('Tech'))),
                    Tab(height: 44, child: Center(child: Text('General'))),
                    Tab(height: 44, child: Center(child: Text('Archived'))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16181F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2029)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search articles...',
                    hintStyle: const TextStyle(color: Color(0xFF5A5A6A)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF5A5A6A)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF5A5A6A)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Article lists or Search Results
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildArticleList(articlesProvider),
                        _buildArticleList(techArticlesProvider),
                        _buildArticleList(generalArticlesProvider),
                        _buildArticleList(archivedArticlesProvider, isArchivedTab: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index != 3 ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddArticleScreen()),
          );
          if (result == true) _invalidateAll();
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ) : null,
    );
  }

  Widget _buildSearchResults() {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final searchAsync = ref.watch(articleSearchProvider(_searchQuery));
        return RefreshIndicator(
          onRefresh: () async => _invalidateAll(),
          color: const Color(0xFF6878FF),
          backgroundColor: const Color(0xFF16181F),
          child: searchAsync.when(
            data: (articles) {
              if (articles.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.search_off_outlined,
                            size: 72,
                            color: Color(0xFF2A2C38),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No results found',
                            style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF5A5A6A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5A5A6A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final addArticleState = ref.watch(addArticleProvider);
                  final isLoading = addArticleState.isArticleLoading(article.id);

                  return LinkPreviewCard(
                    article: article,
                    isLoading: isLoading,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailScreen(article: article),
                      ),
                    ),
                    onArchive: article.isArchived
                        ? () async {
                            await ref.read(newsRepositoryProvider).unarchiveArticle(article.id);
                            _invalidateAll();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Article unarchived')),
                              );
                            }
                          }
                        : () async {
                            await ref.read(newsRepositoryProvider).archiveArticle(article.id);
                            _invalidateAll();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Article archived')),
                              );
                            }
                          },
                    onDelete: () => _showDeleteConfirmation(article),
                    onChangeCategory: () => _showCategoryPicker(article),
                    isArchived: article.isArchived,
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF6878FF)),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildArticleList(FutureProvider<List<NewsArticle>> provider, {bool isArchivedTab = false}) {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final articlesAsync = ref.watch(provider);
        return RefreshIndicator(
          onRefresh: () async => _invalidateAll(),
          color: const Color(0xFF6878FF),
          backgroundColor: const Color(0xFF16181F),
          child: articlesAsync.when(
            data: (articles) {
              if (articles.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Column(
                        children: [
                          Icon(
                            isArchivedTab ? Icons.archive_outlined : Icons.article_outlined, 
                            size: 72, 
                            color: const Color(0xFF2A2C38)
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isArchivedTab ? 'No archived articles' : 'No articles yet',
                            style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF5A5A6A)),
                          ),
                          if (isArchivedTab) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Archive articles to see them here',
                              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5A5A6A)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  // Check if this specific article is being fetched
                  final addArticleState = ref.watch(addArticleProvider);
                  final isLoading = addArticleState.isArticleLoading(article.id);
                  
                  return LinkPreviewCard(
                    article: article,
                    isLoading: isLoading,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailScreen(article: article),
                      ),
                    ),
                    onArchive: isArchivedTab
                        ? () async {
                            await ref.read(newsRepositoryProvider).unarchiveArticle(article.id);
                            _invalidateAll();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Article unarchived')),
                              );
                            }
                          }
                        : () async {
                            await ref.read(newsRepositoryProvider).archiveArticle(article.id);
                            _invalidateAll();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Article archived')),
                              );
                            }
                          },
                    onDelete: () => _showDeleteConfirmation(article),
                    onChangeCategory: () => _showCategoryPicker(article),
                    isArchived: isArchivedTab,
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF6878FF)),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
