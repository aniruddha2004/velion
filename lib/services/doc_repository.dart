import 'dart:io';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/doc_group.dart';
import '../models/doc_document.dart';

class DocRepository {
  static final DocRepository _instance = DocRepository._internal();
  factory DocRepository() => _instance;
  DocRepository._internal();

  Box<DocGroup>? _groupsBox;
  Box<DocDocument>? _documentsBox;
  final _uuid = const Uuid();

  Future<Box<DocGroup>> get _groupsBoxAsync async {
    _groupsBox ??= Hive.box<DocGroup>('docGroups');
    return _groupsBox!;
  }

  Future<Box<DocDocument>> get _documentsBoxAsync async {
    _documentsBox ??= Hive.box<DocDocument>('docDocuments');
    return _documentsBox!;
  }

  Future<Directory> get _docsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(path.join(appDir.path, 'velion_docs'));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir;
  }

  // Groups
  Future<List<DocGroup>> getAllGroups() async {
    final box = await _groupsBoxAsync;
    final groups = box.values.toList();
    groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return groups;
  }

  Future<DocGroup?> getGroupById(String id) async {
    final box = await _groupsBoxAsync;
    return box.get(id);
  }

  Future<DocGroup> createGroup({
    required String name,
    String? description,
  }) async {
    final box = await _groupsBoxAsync;
    final group = DocGroup.create(
      name: name,
      description: description,
    );
    await box.put(group.id, group);
    return group;
  }

  Future<void> updateGroup(DocGroup group) async {
    final box = await _groupsBoxAsync;
    final updated = group.copyWith(updatedAt: DateTime.now());
    await box.put(group.id, updated);
  }

  Future<void> renameGroup(String id, String newName, {String? newDescription}) async {
    final box = await _groupsBoxAsync;
    final group = await getGroupById(id);
    if (group != null) {
      final updated = group.copyWith(
        name: newName,
        description: newDescription ?? group.description,
        updatedAt: DateTime.now(),
      );
      await box.put(id, updated);
    }
  }

  Future<void> renameDocument(String id, String newName, {String? newDescription}) async {
    final box = await _documentsBoxAsync;
    final doc = await getDocumentById(id);
    if (doc != null) {
      final updated = doc.copyWith(
        name: newName,
        description: newDescription ?? doc.description,
        updatedAt: DateTime.now(),
      );
      await box.put(id, updated);
    }
  }

  Future<DocDocument?> copyDocumentToGroup(String documentId, String targetGroupId) async {
    final documentsBox = await _documentsBoxAsync;
    final groupsBox = await _groupsBoxAsync;
    
    final sourceDoc = await getDocumentById(documentId);
    if (sourceDoc == null) return null;
    
    // Copy the actual file
    final sourceFile = File(sourceDoc.filePath);
    if (!await sourceFile.exists()) return null;
    
    final docsDir = await _docsDirectory;
    final extension = path.extension(sourceDoc.filePath);
    final newFileName = '${const Uuid().v4()}$extension';
    final destPath = path.join(docsDir.path, newFileName);
    await sourceFile.copy(destPath);
    
    // Create new document record
    final newDoc = DocDocument.create(
      groupId: targetGroupId,
      name: sourceDoc.name,
      description: sourceDoc.description,
      filePath: destPath,
      mimeType: sourceDoc.mimeType,
      fileSize: sourceDoc.fileSize,
    );
    
    await documentsBox.put(newDoc.id, newDoc);
    
    // Update target group's document list
    final targetGroup = await getGroupById(targetGroupId);
    if (targetGroup != null) {
      final updatedIds = [...targetGroup.documentIds, newDoc.id];
      final updatedGroup = targetGroup.copyWith(
        documentIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await groupsBox.put(targetGroupId, updatedGroup);
    }
    
    return newDoc;
  }

  Future<DocDocument?> moveDocumentToGroup(String documentId, String targetGroupId) async {
    final documentsBox = await _documentsBoxAsync;
    final groupsBox = await _groupsBoxAsync;
    
    final doc = await getDocumentById(documentId);
    if (doc == null) return null;
    
    final sourceGroupId = doc.groupId;
    
    // Update document's group
    final updatedDoc = doc.copyWith(
      groupId: targetGroupId,
      updatedAt: DateTime.now(),
    );
    await documentsBox.put(documentId, updatedDoc);
    
    // Remove from source group
    final sourceGroup = await getGroupById(sourceGroupId);
    if (sourceGroup != null) {
      final updatedIds = sourceGroup.documentIds.where((id) => id != documentId).toList();
      final updatedGroup = sourceGroup.copyWith(
        documentIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await groupsBox.put(sourceGroupId, updatedGroup);
    }
    
    // Add to target group
    final targetGroup = await getGroupById(targetGroupId);
    if (targetGroup != null) {
      final updatedIds = [...targetGroup.documentIds, documentId];
      final updatedGroup = targetGroup.copyWith(
        documentIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await groupsBox.put(targetGroupId, updatedGroup);
    }
    
    return updatedDoc;
  }

  Future<void> deleteGroup(String id) async {
    final groupsBox = await _groupsBoxAsync;
    final documentsBox = await _documentsBoxAsync;
    
    // Delete all documents in the group
    final group = await getGroupById(id);
    if (group != null) {
      for (final docId in group.documentIds) {
        final doc = documentsBox.get(docId);
        if (doc != null) {
          // Delete physical file
          final file = File(doc.filePath);
          if (await file.exists()) {
            await file.delete();
          }
          await documentsBox.delete(docId);
        }
      }
    }
    
    await groupsBox.delete(id);
  }

  Future<int> getGroupCount() async {
    final box = await _groupsBoxAsync;
    return box.length;
  }

  // Documents
  Future<List<DocDocument>> getDocumentsInGroup(String groupId) async {
    final box = await _documentsBoxAsync;
    return box.values.where((doc) => doc.groupId == groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<DocDocument?> getDocumentById(String id) async {
    final box = await _documentsBoxAsync;
    return box.get(id);
  }

  Future<DocDocument> addDocument({
    required String groupId,
    required String name,
    String? description,
    required File sourceFile,
    String? mimeType,
  }) async {
    final documentsBox = await _documentsBoxAsync;
    final groupsBox = await _groupsBoxAsync;
    
    // Copy file to app directory
    final docsDir = await _docsDirectory;
    final extension = path.extension(sourceFile.path);
    final fileName = '${_uuid.v4()}$extension';
    final destPath = path.join(docsDir.path, fileName);
    await sourceFile.copy(destPath);
    
    // Create document record
    final document = DocDocument.create(
      groupId: groupId,
      name: name,
      description: description,
      filePath: destPath,
      mimeType: mimeType ?? _getMimeType(extension),
      fileSize: await sourceFile.length(),
    );
    
    await documentsBox.put(document.id, document);
    
    // Update group's document list
    final group = await getGroupById(groupId);
    if (group != null) {
      final updatedIds = [...group.documentIds, document.id];
      final updatedGroup = group.copyWith(
        documentIds: updatedIds,
        updatedAt: DateTime.now(),
      );
      await groupsBox.put(groupId, updatedGroup);
    }
    
    return document;
  }

  Future<void> deleteDocument(String id) async {
    final box = await _documentsBoxAsync;
    final doc = await getDocumentById(id);
    
    if (doc != null) {
      // Delete physical file
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from group's document list
      final groupsBox = await _groupsBoxAsync;
      final group = await getGroupById(doc.groupId);
      if (group != null) {
        final updatedIds = group.documentIds.where((docId) => docId != id).toList();
        final updatedGroup = group.copyWith(
          documentIds: updatedIds,
          updatedAt: DateTime.now(),
        );
        await groupsBox.put(group.id, updatedGroup);
      }
      
      await box.delete(id);
    }
  }

  Future<int> getDocumentCount() async {
    final box = await _documentsBoxAsync;
    return box.length;
  }

  Future<int> getDocumentCountInGroup(String groupId) async {
    final docs = await getDocumentsInGroup(groupId);
    return docs.length;
  }

  // Search
  Future<List<DocGroup>> searchGroups(String query) async {
    final groups = await getAllGroups();
    final lowerQuery = query.toLowerCase();
    return groups.where((group) {
      return group.name.toLowerCase().contains(lowerQuery) ||
          (group.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  Future<List<DocDocument>> searchDocuments(String query) async {
    final box = await _documentsBoxAsync;
    final lowerQuery = query.toLowerCase();
    return box.values.where((doc) {
      return doc.name.toLowerCase().contains(lowerQuery) ||
          (doc.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.txt':
        return 'text/plain';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }
}
