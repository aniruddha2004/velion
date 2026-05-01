import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_article.dart';
import '../services/news_repository.dart';
import '../services/link_preview_service.dart';
import '../services/category_service.dart';

final newsRepositoryProvider = Provider((ref) => NewsRepository());

final linkPreviewServiceProvider = Provider((ref) => LinkPreviewService());

final articlesProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getActiveArticles();
});

final archivedArticlesProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getArchivedArticles();
});

final techArticlesProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getArticlesByCategory('tech');
});

final generalArticlesProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getArticlesByCategory('general');
});

final unreadArticlesProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getUnreadArticles();
});

final articleCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getArticleCount();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getUnreadCount();
});

final techCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getCategoryCount('tech');
});

final generalCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getCategoryCount('general');
});

final archivedCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.getArchivedCount();
});

// Search provider
final articleSearchProvider = FutureProvider.family<List<NewsArticle>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(newsRepositoryProvider);
  return await repository.searchArticles(query);
});

class AddArticleState {
  final bool isLoading;
  final String? error;
  final Set<String> loadingArticleIds; // Track which articles are being fetched

  const AddArticleState({
    this.isLoading = false,
    this.error,
    this.loadingArticleIds = const {},
  });

  AddArticleState copyWith({
    bool? isLoading,
    String? error,
    Set<String>? loadingArticleIds,
  }) {
    return AddArticleState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      loadingArticleIds: loadingArticleIds ?? this.loadingArticleIds,
    );
  }

  bool isArticleLoading(String articleId) => loadingArticleIds.contains(articleId);
}

class AddArticleNotifier extends StateNotifier<AddArticleState> {
  final Ref _ref;

  AddArticleNotifier(this._ref) : super(const AddArticleState());

  Future<NewsArticle?> addArticle(String url) async {
    if (url.isEmpty) {
      state = state.copyWith(error: 'Please enter a URL');
      return null;
    }

    String normalizedUrl = url.trim();
    if (!normalizedUrl.startsWith('http')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    try {
      Uri.parse(normalizedUrl);
    } catch (_) {
      state = state.copyWith(error: 'Invalid URL');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Declare article outside try block so it's accessible in catch
    late NewsArticle article;

    try {
      final repository = _ref.read(newsRepositoryProvider);
      
      final exists = await repository.articleExists(normalizedUrl);
      if (exists) {
        state = state.copyWith(isLoading: false, error: 'Article already exists');
        return null;
      }

      // Add article immediately with just the URL so it appears in the list
      article = await repository.addArticle(url: normalizedUrl);
      
      // Track this article as loading
      state = state.copyWith(
        isLoading: true,
        loadingArticleIds: {...state.loadingArticleIds, article.id},
      );
      
      // Invalidate to show the article in the list immediately
      _invalidateAll();

      // Fetch preview and full content in background
      final previewService = _ref.read(linkPreviewServiceProvider);
      final preview = await previewService.fetchPreview(normalizedUrl);
      final fullContent = await previewService.fetchFullArticleContent(normalizedUrl);

      // Update the article with fetched data and re-categorize
      if (preview.title != null || preview.description != null || preview.imageUrl != null) {
        // Re-categorize with the new metadata
        final newCategory = CategoryService.categorize(
          url: normalizedUrl,
          title: preview.title,
          description: preview.description,
          siteName: preview.siteName,
        );
        
        article = article.copyWith(
          title: preview.title ?? article.title,
          description: preview.description ?? article.description,
          imageUrl: preview.imageUrl ?? article.imageUrl,
          faviconUrl: preview.faviconUrl ?? article.faviconUrl,
          siteName: preview.siteName ?? article.siteName,
          fullContent: fullContent ?? article.fullContent,
          category: newCategory,
        );
        await repository.updateArticle(article);
        _invalidateAll();
      }

      // Remove from loading set
      final newLoadingIds = Set<String>.from(state.loadingArticleIds)..remove(article.id);
      state = state.copyWith(isLoading: false, loadingArticleIds: newLoadingIds);
      return article;
    } catch (e) {
      // Remove article from loading set on error - CRITICAL FIX
      final newLoadingIds = Set<String>.from(state.loadingArticleIds)..remove(article.id);
      state = state.copyWith(
        isLoading: false, 
        error: 'Failed to add article: $e',
        loadingArticleIds: newLoadingIds,
      );
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void _invalidateAll() {
    _ref.invalidate(articlesProvider);
    _ref.invalidate(archivedArticlesProvider);
    _ref.invalidate(techArticlesProvider);
    _ref.invalidate(generalArticlesProvider);
    _ref.invalidate(unreadArticlesProvider);
    _ref.invalidate(articleCountProvider);
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(techCountProvider);
    _ref.invalidate(generalCountProvider);
    _ref.invalidate(archivedCountProvider);
  }
}

final addArticleProvider = StateNotifierProvider<AddArticleNotifier, AddArticleState>(
  (ref) => AddArticleNotifier(ref),
);
