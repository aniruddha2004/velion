import 'package:hive/hive.dart';

part 'news_article.g.dart';

@HiveType(typeId: 0)
class NewsArticle extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String? title;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final String? faviconUrl;

  @HiveField(6)
  final String? siteName;

  @HiveField(7)
  final DateTime addedAt;

  @HiveField(8)
  bool isRead;

  @HiveField(9)
  String category; // 'tech' or 'general'

  @HiveField(10)
  bool isArchived;

  NewsArticle({
    required this.id,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.faviconUrl,
    this.siteName,
    required this.addedAt,
    this.isRead = false,
    this.category = 'general',
    this.isArchived = false,
  });

  NewsArticle copyWith({
    String? id,
    String? url,
    String? title,
    String? description,
    String? imageUrl,
    String? faviconUrl,
    String? siteName,
    DateTime? addedAt,
    bool? isRead,
    String? category,
    bool? isArchived,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      siteName: siteName ?? this.siteName,
      addedAt: addedAt ?? this.addedAt,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  String get displayTitle => title ?? 'Untitled Article';

  String get displayDescription => description ?? '';

  String get hostName {
    try {
      final uri = Uri.parse(url);
      return siteName ?? uri.host.replaceAll('www.', '');
    } catch (_) {
      return 'Unknown Source';
    }
  }
}
