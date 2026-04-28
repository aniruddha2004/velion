import 'package:objectbox/objectbox.dart';

@Entity()
class ChatMessageEntity {
  @Id()
  int id;

  String sessionId;
  String articleId;
  String role; // 'user' or 'assistant'
  String content;
  int createdAt;

  ChatMessageEntity({
    this.id = 0,
    required this.sessionId,
    required this.articleId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

@Entity()
class ArticleEmbedding {
  @Id()
  int id;

  String articleId;
  String content;

  @HnswIndex(
    dimensions: 768,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  ArticleEmbedding({
    this.id = 0,
    required this.articleId,
    required this.content,
    this.embedding,
  });
}
