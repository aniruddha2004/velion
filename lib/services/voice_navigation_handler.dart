import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/news/news_home_screen.dart';
import '../screens/doc/doc_home_screen.dart';
import '../screens/doc/doc_group_detail_screen.dart';
import '../screens/doc/document_viewer_screen.dart';
import '../providers/news_provider.dart';
import '../providers/doc_provider.dart';
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
    final target = intent.target;
    final groupHint = intent.groupHint;

    // Get all groups using repository
    final repository = _ref.read(docRepositoryProvider);
    final groups = await repository.getAllGroups();

    if (groups.isEmpty) {
      _showError('No document groups found');
      return;
    }

    // Find matching group
    DocGroup? matchingGroup;
    
    // First try exact match on group hint
    if (groupHint != null && groupHint.isNotEmpty) {
      try {
        matchingGroup = groups.firstWhere(
          (g) => g.name.toLowerCase() == groupHint.toLowerCase(),
        );
      } catch (_) {
        try {
          matchingGroup = groups.firstWhere(
            (g) => g.name.toLowerCase().contains(groupHint.toLowerCase()),
          );
        } catch (_) {
          matchingGroup = null;
        }
      }
    }

    // If no group hint or no match, search in all groups
    if (matchingGroup == null) {
      // Try to find a group that matches the target name
      try {
        matchingGroup = groups.firstWhere(
          (g) => g.name.toLowerCase().contains(target.toLowerCase()),
        );
      } catch (_) {
        matchingGroup = groups.first;
      }
    }

    if (matchingGroup == null) {
      _showError('Could not find a matching group');
      return;
    }

    // Get documents in the matching group
    final documents = await repository.getDocumentsInGroup(matchingGroup.id);

    if (documents.isEmpty) {
      // Navigate to group but show empty state
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

    // Find best matching document
    DocDocument? matchingDoc;
    
    // Try exact match first
    try {
      matchingDoc = documents.firstWhere(
        (d) => d.name.toLowerCase().contains(target.toLowerCase()),
      );
    } catch (_) {
      matchingDoc = documents.first;
    }

    if (matchingDoc == null) {
      _showError('No documents found');
      return;
    }

    // Open document directly - skip group screen for cleaner UX
    if (!mounted) return;

    final ext = matchingDoc.fileExtension.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    final isPdf = ext == 'pdf';

    if (isImage || isPdf) {
      // Navigate directly to document viewer
      Navigator.push(
        _context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(document: matchingDoc!),
        ),
      );
      _showSuccess('Opened ${matchingDoc.name}');
    } else {
      // For non-viewable files, open the group
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
