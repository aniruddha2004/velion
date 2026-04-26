import 'package:flutter/material.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = [
      _FeatureCard(
        icon: Icons.note_alt_outlined,
        title: 'Notes',
        description: 'Capture thoughts and ideas instantly',
        gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      ),
      _FeatureCard(
        icon: Icons.task_alt_outlined,
        title: 'Tasks',
        description: 'Organize your daily to-dos',
        gradient: const [Color(0xFF4ECDC4), Color(0xFF44B09E)],
      ),
      _FeatureCard(
        icon: Icons.bookmark_outline_rounded,
        title: 'Bookmarks',
        description: 'Save anything for later',
        gradient: const [Color(0xFFA18CD1), Color(0xFFC084FC)],
      ),
      _FeatureCard(
        icon: Icons.alarm_outlined,
        title: 'Reminders',
        description: 'Never miss important moments',
        gradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
      ),
      _FeatureCard(
        icon: Icons.analytics_outlined,
        title: 'Insights',
        description: 'Track your reading habits',
        gradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      ),
      _FeatureCard(
        icon: Icons.tag_outlined,
        title: 'Collections',
        description: 'Group articles by topics',
        gradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'More features coming soon to Velion',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFA6ADBD),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final feature = features[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
                      ),
                      child: Stack(
                        children: [
                          // Gradient glow at top
                          Positioned(
                            top: -20,
                            left: -20,
                            right: -20,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: feature.gradient.map((c) => c.withOpacity(0.15)).toList(),
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          // Lock overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF0B0D12).withOpacity(0.4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: feature.gradient),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: feature.gradient[0].withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(feature.icon, color: Colors.white, size: 22),
                                ),
                                const Spacer(),
                                Text(
                                  feature.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  feature.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFA6ADBD),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: feature.gradient[0].withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        size: 12,
                                        color: feature.gradient[0],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Coming Soon',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: feature.gradient[0],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: features.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
