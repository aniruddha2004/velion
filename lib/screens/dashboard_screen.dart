import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/news_provider.dart';
import 'add_article_screen.dart';
import 'article_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(articlesProvider);
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final articleCountAsync = ref.watch(articleCountProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient orb
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.15),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(articlesProvider);
                ref.invalidate(unreadCountProvider);
                ref.invalidate(articleCountProvider);
              },
              color: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1A1A2E),
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
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252540),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Color(0xFF9E9EBF),
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Greeting
                          Text(
                            _getGreeting(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF9E9EBF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Welcome to ',
                                style: theme.textTheme.headlineLarge,
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                                ).createShader(bounds),
                                child: Text(
                                  'Velion',
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Stats row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          _StatCard(
                            icon: Icons.article_outlined,
                            label: 'Total',
                            valueAsync: articleCountAsync,
                            gradient: const [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.mark_email_unread_outlined,
                            label: 'Unread',
                            valueAsync: unreadCountAsync,
                            gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.today_outlined,
                            label: 'Today',
                            valueAsync: articlesAsync.when(
                              data: (articles) {
                                final today = DateTime.now();
                                final count = articles.where((a) =>
                                  a.addedAt.year == today.year &&
                                  a.addedAt.month == today.month &&
                                  a.addedAt.day == today.day
                                ).length;
                                return AsyncValue.data(count);
                              },
                              loading: () => const AsyncValue.loading(),
                              error: (e, _) => const AsyncValue.data(0),
                            ),
                            gradient: const [Color(0xFF00D9FF), Color(0xFF38BDF8)],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Add Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddArticleScreen(),
                            ),
                          );
                          if (result == true) {
                            ref.invalidate(articlesProvider);
                            ref.invalidate(unreadCountProvider);
                            ref.invalidate(articleCountProvider);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add_link_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add New Article',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Paste a link or share from any app',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Recent Saves
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Saves',
                            style: theme.textTheme.titleLarge,
                          ),
                          articlesAsync.when(
                            data: (articles) => articles.length > 3
                                ? TextButton(
                                    onPressed: () {
                                      // Switch to News tab by finding MainShell
                                    },
                                    child: const Text('See all'),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recent articles
                  articlesAsync.when(
                    data: (articles) {
                      if (articles.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 64,
                                  color: const Color(0xFF3D3D5C),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No articles yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF5A5A7A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Save your first article to get started',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF3D3D5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final recent = articles.take(3).toList();
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final article = recent[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                              child: _RecentArticleTile(
                                article: article,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ArticleDetailScreen(article: article),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: recent.length,
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
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final AsyncValue<int> valueAsync;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.valueAsync,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF252540), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 10),
            valueAsync.when(
              data: (value) => Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
              ),
              error: (_, __) => const Text('-', style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A7A9A),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentArticleTile extends StatelessWidget {
  final dynamic article;
  final VoidCallback onTap;

  const _RecentArticleTile({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF252540), width: 0.5),
        ),
        child: Row(
          children: [
            // Image or placeholder
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _imagePlaceholder(),
                ),
              )
            else
              _imagePlaceholder(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.displayTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.hostName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                ],
              ),
            ),
            if (!article.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF252540), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.article_outlined, color: Color(0xFF3D3D5C), size: 24),
    );
  }
}
