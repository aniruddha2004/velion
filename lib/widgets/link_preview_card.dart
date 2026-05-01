import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/news_article.dart';

class LinkPreviewCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCategory;
  final bool isArchived;
  final bool isLoading; // Show loading state while fetching preview

  const LinkPreviewCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onArchive,
    this.onDelete,
    this.onChangeCategory,
    this.isArchived = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTech = article.category == 'tech';
    
    // Show loading skeleton when fetching preview
    if (isLoading) {
      return _buildLoadingCard();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16181F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2029), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1E2029), Color(0xFF16181F)]),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6878FF)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1E2029), Color(0xFF16181F)]),
                      ),
                      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF2A2C38), size: 48),
                    ),
                  ),
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, const Color(0xFF16181F).withOpacity(0.9)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 14, left: 14, child: _categoryBadge(isTech)),
                  if (!article.isRead)
                    Positioned(
                      top: 14, right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6878FF), Color(0xFF3B82F6)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF6878FF).withOpacity(0.4), blurRadius: 8)],
                        ),
                        child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl == null)
                    Row(
                      children: [
                        _categoryBadgeSmall(isTech),
                        const Spacer(),
                        if (!article.isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6878FF), shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: const Color(0xFF6878FF).withOpacity(0.5), blurRadius: 6)],
                            ),
                          ),
                      ],
                    ),
                  if (article.imageUrl == null) const SizedBox(height: 10),
                  Row(
                    children: [
                      if (article.faviconUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: article.faviconUrl!, width: 16, height: 16,
                            placeholder: (_, __) => _sourceIcon(),
                            errorWidget: (_, __, ___) => _sourceIcon(),
                          ),
                        )
                      else
                        _sourceIcon(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          article.hostName.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF6878FF), fontWeight: FontWeight.w700, letterSpacing: 0.8,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.access_time_rounded, size: 13, color: const Color(0xFF5A5A6A)),
                      const SizedBox(width: 4),
                      Text(_formatDate(article.addedAt), style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF5A5A6A))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(article.displayTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (article.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(article.displayDescription, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFA6ADBD), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6878FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.open_in_new_rounded, size: 14, color: const Color(0xFF6878FF)),
                                const SizedBox(width: 6),
                                Text('Open', style: TextStyle(color: const Color(0xFF6878FF), fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(icon: Icons.swap_horiz_rounded, onTap: onChangeCategory),
                      const SizedBox(width: 6),
                      _actionButton(icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, onTap: onArchive),
                      const SizedBox(width: 6),
                      _actionButton(icon: Icons.delete_outline_rounded, onTap: onDelete, color: const Color(0xFFFF5252)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, VoidCallback? onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFFA6ADBD)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color ?? const Color(0xFFA6ADBD)),
      ),
    );
  }

  Widget _categoryBadge(bool isTech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isTech ? const [Color(0xFF6878FF), Color(0xFF3B82F6)] : const [Color(0xFF4ECDC4), Color(0xFF44B09E)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTech ? Icons.computer_outlined : Icons.public_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(isTech ? 'TECH' : 'GENERAL', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _categoryBadgeSmall(bool isTech) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isTech ? const [Color(0xFF6878FF), Color(0xFF3B82F6)] : const [Color(0xFF4ECDC4), Color(0xFF44B09E)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTech ? Icons.computer_outlined : Icons.public_outlined, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(isTech ? 'TECH' : 'GENERAL', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _sourceIcon() {
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: const Color(0xFF1E2029), borderRadius: BorderRadius.circular(4)),
      child: const Icon(Icons.language, size: 10, color: Color(0xFF6878FF)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  Widget _buildLoadingCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E2029),
      highlightColor: const Color(0xFF2A2C38),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16181F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder for image
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2029),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Placeholder for source row
                  Row(
                    children: [
                      Container(width: 16, height: 16, color: const Color(0xFF1E2029)),
                      const SizedBox(width: 8),
                      Container(width: 80, height: 12, color: const Color(0xFF1E2029)),
                      const Spacer(),
                      Container(width: 60, height: 10, color: const Color(0xFF1E2029)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Placeholder for title
                  Container(width: double.infinity, height: 18, color: const Color(0xFF1E2029)),
                  const SizedBox(height: 8),
                  Container(width: double.infinity * 0.7, height: 18, color: const Color(0xFF1E2029)),
                  const SizedBox(height: 8),
                  // Placeholder for description
                  Container(width: double.infinity, height: 14, color: const Color(0xFF1E2029)),
                  const SizedBox(height: 6),
                  Container(width: double.infinity * 0.8, height: 14, color: const Color(0xFF1E2029)),
                  const SizedBox(height: 16),
                  // Placeholder for action buttons
                  Row(
                    children: [
                      Expanded(child: Container(height: 36, color: const Color(0xFF1E2029))),
                      const SizedBox(width: 8),
                      Container(width: 36, height: 36, color: const Color(0xFF1E2029)),
                      const SizedBox(width: 6),
                      Container(width: 36, height: 36, color: const Color(0xFF1E2029)),
                      const SizedBox(width: 6),
                      Container(width: 36, height: 36, color: const Color(0xFF1E2029)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
