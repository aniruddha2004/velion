import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'doc_document.g.dart';

@HiveType(typeId: 2)
class DocDocument extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String groupId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final String filePath;

  @HiveField(5)
  final String? mimeType;

  @HiveField(6)
  final int? fileSize;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  DocDocument({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    required this.filePath,
    this.mimeType,
    this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });

  DocDocument copyWith({
    String? id,
    String? groupId,
    String? name,
    String? description,
    String? filePath,
    String? mimeType,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocDocument(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DocDocument create({
    required String groupId,
    required String name,
    String? description,
    required String filePath,
    String? mimeType,
    int? fileSize,
  }) {
    final now = DateTime.now();
    return DocDocument(
      id: const Uuid().v4(),
      groupId: groupId,
      name: name,
      description: description,
      filePath: filePath,
      mimeType: mimeType,
      fileSize: fileSize,
      createdAt: now,
      updatedAt: now,
    );
  }

  String get displaySize {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '${fileSize!} B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot == -1) return '';
    return name.substring(lastDot + 1).toLowerCase();
  }

  IconData get icon {
    switch (fileExtension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      case 'txt':
      case 'md':
        return Icons.description;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
