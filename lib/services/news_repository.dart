import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/news_article.dart';

class NewsRepository {
  static final NewsRepository _instance = NewsRepository._internal();
  factory NewsRepository() => _instance;
  NewsRepository._internal();

  Box<NewsArticle>? _box;
  final _uuid = const Uuid();

  Future<Box<NewsArticle>> get _newsBox async {
    _box ??= Hive.box<NewsArticle>('newsArticles');
    return _box!;
  }

  Future<List<NewsArticle>> getAllArticles() async {
    final box = await _newsBox;
    final articles = box.values.toList();
    articles.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return articles;
  }

  Future<List<NewsArticle>> getUnreadArticles() async {
    final articles = await getAllArticles();
    return articles.where((a) => !a.isRead).toList();
  }

  Future<NewsArticle?> getArticleById(String id) async {
    final box = await _newsBox;
    return box.get(id);
  }

  Future<NewsArticle> addArticle({
    required String url,
    String? title,
    String? description,
    String? imageUrl,
    String? faviconUrl,
    String? siteName,
  }) async {
    final box = await _newsBox;
    
    final article = NewsArticle(
      id: _uuid.v4(),
      url: url,
      title: title,
      description: description,
      imageUrl: imageUrl,
      faviconUrl: faviconUrl,
      siteName: siteName,
      addedAt: DateTime.now(),
    );

    await box.put(article.id, article);
    return article;
  }

  Future<void> updateArticle(NewsArticle article) async {
    final box = await _newsBox;
    await box.put(article.id, article);
  }

  Future<void> markAsRead(String id) async {
    final box = await _newsBox;
    final article = box.get(id);
    if (article != null) {
      article.isRead = true;
      await article.save();
    }
  }

  Future<void> markAsUnread(String id) async {
    final box = await _newsBox;
    final article = box.get(id);
    if (article != null) {
      article.isRead = false;
      await article.save();
    }
  }

  Future<void> deleteArticle(String id) async {
    final box = await _newsBox;
    await box.delete(id);
  }

  Future<bool> articleExists(String url) async {
    final articles = await getAllArticles();
    return articles.any((a) => a.url == url);
  }

  Future<int> getArticleCount() async {
    final box = await _newsBox;
    return box.length;
  }

  Future<int> getUnreadCount() async {
    final articles = await getAllArticles();
    return articles.where((a) => !a.isRead).length;
  }
}
