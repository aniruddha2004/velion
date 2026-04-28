import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';
import '../models/objectbox_entities.dart';

class ObjectBoxService {
  static final ObjectBoxService _instance = ObjectBoxService._internal();
  factory ObjectBoxService() => _instance;
  ObjectBoxService._internal();

  Store? _store;

  Future<Store> get store async {
    if (_store != null && !_store!.isClosed()) return _store!;
    final docsDir = await getApplicationDocumentsDirectory();
    _store = await openStore(
      directory: p.join(docsDir.path, 'velion-objectbox'),
    );
    return _store!;
  }

  Future<void> close() async {
    if (_store != null && !_store!.isClosed()) {
      _store!.close();
      _store = null;
    }
  }

  // === Chat Messages ===

  Future<void> saveMessage(ChatMessageEntity message) async {
    final s = await store;
    s.box<ChatMessageEntity>().put(message);
  }

  Future<List<ChatMessageEntity>> getSessionMessages(String sessionId) async {
    final s = await store;
    final query = s.box<ChatMessageEntity>()
        .query(ChatMessageEntity_.sessionId.equals(sessionId))
        .order(ChatMessageEntity_.createdAt)
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  Future<void> clearSession(String sessionId) async {
    final s = await store;
    final query = s.box<ChatMessageEntity>()
        .query(ChatMessageEntity_.sessionId.equals(sessionId))
        .build();
    final results = query.find();
    query.close();
    if (results.isNotEmpty) {
      s.box<ChatMessageEntity>().removeMany(results.map((m) => m.id).toList());
    }
  }

  // === Article Embeddings ===

  Future<void> saveArticleEmbedding(ArticleEmbedding embedding) async {
    final s = await store;
    // Remove existing embedding for this article
    final query = s.box<ArticleEmbedding>()
        .query(ArticleEmbedding_.articleId.equals(embedding.articleId))
        .build();
    final existing = query.find();
    query.close();
    if (existing.isNotEmpty) {
      s.box<ArticleEmbedding>().removeMany(existing.map((e) => e.id).toList());
    }
    s.box<ArticleEmbedding>().put(embedding);
  }

  Future<ArticleEmbedding?> getArticleEmbedding(String articleId) async {
    final s = await store;
    final query = s.box<ArticleEmbedding>()
        .query(ArticleEmbedding_.articleId.equals(articleId))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<void> deleteArticleEmbedding(String articleId) async {
    final s = await store;
    final query = s.box<ArticleEmbedding>()
        .query(ArticleEmbedding_.articleId.equals(articleId))
        .build();
    final existing = query.find();
    query.close();
    if (existing.isNotEmpty) {
      s.box<ArticleEmbedding>().removeMany(existing.map((e) => e.id).toList());
    }
  }
}
