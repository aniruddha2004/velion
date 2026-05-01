import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'doc_group.g.dart';

@HiveType(typeId: 1)
class DocGroup extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final List<String> documentIds;

  DocGroup({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.documentIds = const [],
  });

  DocGroup copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? documentIds,
  }) {
    return DocGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentIds: documentIds ?? this.documentIds,
    );
  }

  static DocGroup create({
    required String name,
    String? description,
  }) {
    final now = DateTime.now();
    return DocGroup(
      id: const Uuid().v4(),
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }
}
