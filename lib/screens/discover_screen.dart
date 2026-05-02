import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/news_provider.dart';
import '../widgets/voice_button.dart';
import '../widgets/voice_overlay.dart';
import 'news/news_home_screen.dart';
import 'doc/doc_home_screen.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final articleCountAsync = ref.watch(articleCountProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with voice button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discover',
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Explore all your features',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFA6ADBD),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VoiceButton(),
                  ],
                ),
              ),
            ),

            // Features Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  // News Feature Card
                  _FeatureCard(
                    icon: Icons.article_outlined,
                    title: 'News',
                    description: 'Save and organize articles from anywhere',
                    gradient: const [Color(0xFF6878FF), Color(0xFF3B82F6)],
                    badgeAsync: articleCountAsync,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NewsHomeScreen()),
                    ),
                  ),

                  // Doc Feature Card
                  _FeatureCard(
                    icon: Icons.folder_outlined,
                    title: 'Docs',
                    description: 'Store and manage your documents in groups',
                    gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DocHomeScreen()),
                    ),
                  ),

                  // Placeholder for future features
                  _FeatureCard(
                    icon: Icons.smart_toy_outlined,
                    title: 'AI Chat',
                    description: 'Coming soon',
                    gradient: const [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
                    isDisabled: true,
                    onTap: () {},
                  ),

                  // Placeholder for future features
                  _FeatureCard(
                    icon: Icons.task_alt_outlined,
                    title: 'Tasks',
                    description: 'Coming soon',
                    gradient: const [Color(0xFFFFB347), Color(0xFFFFCC33)],
                    isDisabled: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final AsyncValue<int>? badgeAsync;
  final bool isDisabled;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    this.badgeAsync,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFF1E2029) : const Color(0xFF16181F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDisabled ? const Color(0xFF2A2C38) : const Color(0xFF1E2029),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                if (badgeAsync != null)
                  badgeAsync!.when(
                    data: (count) => count > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: gradient[0].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: isDisabled ? const Color(0xFF5A5A6A) : const Color(0xFFA6ADBD),
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
