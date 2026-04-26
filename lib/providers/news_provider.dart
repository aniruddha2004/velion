import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news_article.dart';
import '../services/news_repository.dart';
import '../services/link_preview_service.dart';

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

class AddArticleState {
  final bool isLoading;
  final String? error;

  const AddArticleState({
    this.isLoading = false,
    this.error,
  });

  AddArticleState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return AddArticleState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
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

    try {
      final repository = _ref.read(newsRepositoryProvider);
      
      final exists = await repository.articleExists(normalizedUrl);
      if (exists) {
        state = state.copyWith(isLoading: false, error: 'Article already exists');
        return null;
      }

      final previewService = _ref.read(linkPreviewServiceProvider);
      final preview = await previewService.fetchPreview(normalizedUrl);

      final article = await repository.addArticle(
        url: normalizedUrl,
        title: preview.title,
        description: preview.description,
        imageUrl: preview.imageUrl,
        faviconUrl: preview.faviconUrl,
        siteName: preview.siteName,
      );

      state = state.copyWith(isLoading: false);
      _invalidateAll();

      return article;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to add article');
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
