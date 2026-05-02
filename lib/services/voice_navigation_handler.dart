import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/news/news_home_screen.dart';
import '../screens/doc/doc_home_screen.dart';
import '../screens/doc/doc_group_detail_screen.dart';
import '../screens/doc/document_viewer_screen.dart';
import '../providers/news_provider.dart';
import '../providers/doc_provider.dart';
import '../providers/voice_provider.dart';
import '../services/doc_repository.dart';
import '../services/voice_command_service.dart';
import '../models/doc_group.dart';
import '../models/doc_document.dart';

class VoiceNavigationHandler {
  final WidgetRef _ref;
  final BuildContext _context;

  VoiceNavigationHandler(this._ref, this._context);

  Future<void> executeIntent(VoiceIntent intent) async {
    switch (intent.type) {
      case VoiceIntentType.viewDocument:
        await _handleViewDocument(intent);
        break;
      case VoiceIntentType.viewNews:
        await _handleViewNews(intent);
        break;
      case VoiceIntentType.searchNews:
        await _handleSearchNews(intent);
        break;
      case VoiceIntentType.unknown:
        _showError('Sorry, I didn\'t understand that command');
        break;
    }
  }

  Future<void> _handleViewDocument(VoiceIntent intent) async {
    final repository = _ref.read(docRepositoryProvider);
    final groups = await repository.getAllGroups();

    if (groups.isEmpty) {
      _showError('No document groups found');
      return;
    }

    final documentsByGroup = <String, List<DocDocument>>{};
    for (final group in groups) {
      documentsByGroup[group.id] = await repository.getDocumentsInGroup(group.id);
    }

    final voiceCommandService = VoiceCommandService(
      _ref.read(settingsServiceProvider),
      _ref.read(objectBoxServiceProvider),
    );

    final resolution = await voiceCommandService.resolveDocumentSelection(
      intent: intent,
      groups: groups,
      documentsByGroup: documentsByGroup,
    );

    if (resolution == null || !resolution.hasMatch) {
      _showError('Could not find a matching group');
      return;
    }

    DocGroup? matchingGroup;
    for (final group in groups) {
      if (group.id == resolution.groupId) {
        matchingGroup = group;
        break;
      }
    }

    if (matchingGroup == null) {
      _showError('Could not find a matching group');
      return;
    }

    final documents = documentsByGroup[matchingGroup.id] ?? const <DocDocument>[];

    if (documents.isEmpty) {
      if (mounted) {
        Navigator.push(
          _context,
          MaterialPageRoute(
            builder: (_) => DocGroupDetailScreen(groupId: matchingGroup!.id),
          ),
        );
        _showSuccess('Opened ${matchingGroup.name} - no documents found');
      }
      return;
    }

    DocDocument? matchingDoc;
    if (resolution.documentId != null) {
      for (final document in documents) {
        if (document.id == resolution.documentId) {
          matchingDoc = document;
          break;
        }
      }
    }

    if (matchingDoc == null && documents.length == 1) {
      matchingDoc = documents.first;
    }

    if (!mounted) return;

    if (matchingDoc == null) {
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => DocGroupDetailScreen(groupId: matchingGroup!.id),
        ),
      );
      _showSuccess('Opened ${matchingGroup.name}');
      return;
    }

    final ext = matchingDoc.fileExtension.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    final isPdf = ext == 'pdf';

    if (isImage || isPdf) {
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(document: matchingDoc!),
        ),
      );
      _showSuccess('Opened ${matchingDoc.name}');
    } else {
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => DocGroupDetailScreen(groupId: matchingGroup!.id),
        ),
      );
      _showSuccess('Opened ${matchingGroup.name}');
    }
  }

  Future<void> _handleViewNews(VoiceIntent intent) async {
    if (!mounted) return;
    
    // Navigate to news screen
    Navigator.push(
      _context,
      MaterialPageRoute(builder: (_) => const NewsHomeScreen()),
    );

    _showSuccess('Showing news articles');
  }

  Future<void> _handleSearchNews(VoiceIntent intent) async {
    final searchTerm = intent.target;

    if (searchTerm.isEmpty) {
      _showError('Please specify what to search for');
      return;
    }

    if (!mounted) return;

    // Navigate to news with search term
    // We'll store the search term in a provider that NewsHomeScreen can read
    _ref.read(voiceSearchProvider.notifier).state = searchTerm;

    Navigator.push(
      _context,
      MaterialPageRoute(builder: (_) => const NewsHomeScreen()),
    );

    _showSuccess('Searching news for "$searchTerm"');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFFF5252),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF4ECDC4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool get mounted => _context.mounted;
}

// Provider to store voice search term
final voiceSearchProvider = StateProvider<String?>((ref) => null);
