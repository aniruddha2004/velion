import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/doc_group.dart';
import '../models/doc_document.dart';
import '../services/doc_repository.dart';

final docRepositoryProvider = Provider((ref) => DocRepository());

final docGroupsProvider = FutureProvider<List<DocGroup>>((ref) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getAllGroups();
});

final docGroupCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getGroupCount();
});

final docDocumentsProvider = FutureProvider.family<List<DocDocument>, String>((ref, groupId) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getDocumentsInGroup(groupId);
});

final docDocumentCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getDocumentCount();
});

// Search providers
final docGroupSearchProvider = FutureProvider.family<List<DocGroup>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(docRepositoryProvider);
  return await repository.searchGroups(query);
});

final docDocumentSearchProvider = FutureProvider.family<List<DocDocument>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(docRepositoryProvider);
  return await repository.searchDocuments(query);
});

class DocGroupNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DocGroupNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<DocGroup?> createGroup(String name, {String? description}) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(docRepositoryProvider);
      final group = await repository.createGroup(
        name: name,
        description: description,
      );
      _ref.invalidate(docGroupsProvider);
      _ref.invalidate(docGroupCountProvider);
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteGroup(String id) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(docRepositoryProvider);
      await repository.deleteGroup(id);
      _ref.invalidate(docGroupsProvider);
      _ref.invalidate(docGroupCountProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

class DocDocumentNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DocDocumentNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<DocDocument?> addDocument({
    required String groupId,
    required String name,
    String? description,
    required File file,
    String? mimeType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(docRepositoryProvider);
      final document = await repository.addDocument(
        groupId: groupId,
        name: name,
        description: description,
        sourceFile: file,
        mimeType: mimeType,
      );
      _ref.invalidate(docDocumentsProvider(groupId));
      _ref.invalidate(docDocumentCountProvider);
      _ref.invalidate(docGroupsProvider);
      state = const AsyncValue.data(null);
      return document;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteDocument(String id, String groupId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(docRepositoryProvider);
      await repository.deleteDocument(id);
      _ref.invalidate(docDocumentsProvider(groupId));
      _ref.invalidate(docDocumentCountProvider);
      _ref.invalidate(docGroupsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> pickAndAddDocument(String groupId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        await addDocument(
          groupId: groupId,
          name: fileName,
          file: file,
          mimeType: result.files.single.extension != null 
              ? _getMimeType(result.files.single.extension!) 
              : null,
        );
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final docGroupNotifierProvider = StateNotifierProvider<DocGroupNotifier, AsyncValue<void>>(
  (ref) => DocGroupNotifier(ref),
);

final docDocumentNotifierProvider = StateNotifierProvider<DocDocumentNotifier, AsyncValue<void>>(
  (ref) => DocDocumentNotifier(ref),
);
