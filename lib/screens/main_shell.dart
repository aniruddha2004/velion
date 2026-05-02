import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dashboard_screen.dart';
import 'discover_screen.dart';
import 'settings_screen.dart';
import 'news/news_home_screen.dart';
import 'doc/doc_home_screen.dart';
import 'doc/doc_group_detail_screen.dart';
import '../providers/news_provider.dart';
import '../providers/doc_provider.dart';
import '../widgets/persistent_voice_overlay.dart';
import '../models/doc_group.dart';
import '../models/doc_document.dart';

enum ShareTarget { news, docs, unknown }

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  StreamSubscription? _shareSubscription;
  bool _initialShareProcessed = false;
  bool _isProcessingShare = false; // Prevent duplicate processing
  ShareTarget _shareTarget = ShareTarget.unknown;
  String? _lastProcessedShareId; // Track last processed share to prevent duplicates

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _detectShareTarget();
    _initShareReceiver();
  }

  void _detectShareTarget() {
    // This will be set by platform channel in real implementation
    // For now, we'll detect based on intent data
    _shareTarget = ShareTarget.unknown;
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _initShareReceiver() {
    try {
      _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          if (files.isNotEmpty && mounted) {
            _processSharedFiles(files);
          }
        },
        onError: (err) {
          debugPrint('Share receiver stream error: $err');
          _showErrorSnackBar('Share receiver error: $err');
        },
      );

      if (!_initialShareProcessed) {
        ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
          if (files.isNotEmpty && mounted) {
            _processSharedFiles(files);
            ReceiveSharingIntent.instance.reset();
          }
          _initialShareProcessed = true;
        }).catchError((err) {
          debugPrint('getInitialMedia error: $err');
          _initialShareProcessed = true;
        });
      }
    } catch (e) {
      debugPrint('Share receiver init error: $e');
      _showErrorSnackBar('Failed to initialize share receiver: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  void _processSharedFiles(List<SharedMediaFile> files) {
    // Prevent duplicate processing
    if (_isProcessingShare) {
      debugPrint('=== ALREADY PROCESSING SHARE, IGNORING DUPLICATE ===');
      return;
    }

    // Create unique ID for this share batch to prevent duplicates
    final shareId = files.map((f) => '${f.path}_${f.type}').join('_');
    if (shareId == _lastProcessedShareId) {
      debugPrint('=== SHARE ALREADY PROCESSED, IGNORING ===');
      return;
    }

    _isProcessingShare = true;
    _lastProcessedShareId = shareId;

    debugPrint('=== SHARE RECEIVED ===');
    debugPrint('Files count: ${files.length}');
    for (var i = 0; i < files.length; i++) {
      debugPrint('File $i: type=${files[i].type}, path="${files[i].path}"');
    }

    // Determine if this is URL content or file content
    bool hasUrl = false;
    bool hasFile = false;
    String? url;
    List<SharedMediaFile> fileShares = [];

    for (final file in files) {
      final path = file.path;
      
      // Check for URLs in text
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        final extractedUrl = _extractUrlFromText(path);
        if (extractedUrl != null) {
          hasUrl = true;
          url = extractedUrl;
        }
      }
      
      // Check for actual files
      if (file.type == SharedMediaType.image || 
          file.type == SharedMediaType.video ||
          file.type == SharedMediaType.file) {
        hasFile = true;
        fileShares.add(file);
      }
      
      // Also check if path is an actual file path
      if (path.startsWith('/storage/') || path.startsWith('/data/') || path.startsWith('/mnt/')) {
        hasFile = true;
        fileShares.add(file);
      }
    }

    // Reset processing flag after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _isProcessingShare = false;
    });

    // Decision logic - direct routing based on content type
    if (hasUrl && !hasFile) {
      // Only URLs - go directly to News
      _handleNewsShare(url!, fromDocs: false);
    } else if (hasFile && !hasUrl) {
      // Only files - go directly to Docs
      _handleDocsShare(fileShares, fromNews: false);
    } else if (hasUrl && hasFile) {
      // Mixed - show dialog to choose
      _showMixedShareDialog(url!, fileShares);
    } else {
      // Fallback - treat as URL if any http found
      for (final file in files) {
        if (file.path.startsWith('http')) {
          _handleNewsShare(file.path, fromDocs: false);
          return;
        }
      }
      // Otherwise treat as file
      if (files.isNotEmpty) {
        _handleDocsShare(files, fromNews: false);
      }
    }
  }
  
  String? _extractUrlFromText(String text) {
    final patterns = [
      RegExp(r'https?://[^\s<>"\)\]\n]+', caseSensitive: false),
      RegExp(r'share\.google/[^\s<>"\)\]\n]+', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var url = match.group(0)!;
        if (!url.startsWith('http')) {
          url = 'https://$url';
        }
        return url;
      }
    }
    return null;
  }

  void _showMixedShareDialog(String url, List<SharedMediaFile> files) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: const Text('What would you like to save?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShareOptionTile(
              icon: Icons.article_outlined,
              title: 'Save Article Link',
              subtitle: 'Add to News section',
              onTap: () {
                Navigator.pop(context);
                _handleNewsShare(url, fromDocs: false);
              },
            ),
            const SizedBox(height: 12),
            _ShareOptionTile(
              icon: Icons.folder_outlined,
              title: 'Save Files',
              subtitle: 'Add to Documents (${files.length} file${files.length > 1 ? 's' : ''})',
              onTap: () {
                Navigator.pop(context);
                _handleDocsShare(files, fromNews: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleNewsShare(String url, {required bool fromDocs}) async {
    // Force navigate to News screen
    setState(() {
      _currentIndex = 1; // Discover tab
    });
    
    // Navigate to News screen
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewsHomeScreen()),
      );
    }

    final notifier = ref.read(addArticleProvider.notifier);
    final article = await notifier.addArticle(url);

    _isProcessingShare = false;

    if (mounted) {
      if (article != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Article added: ${article.displayTitle}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final state = ref.read(addArticleProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error ?? 'Failed to add article'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleDocsShare(List<SharedMediaFile> files, {required bool fromNews}) async {
    // Force navigate to Docs screen
    setState(() {
      _currentIndex = 1; // Discover tab
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Show group selection dialog
    final result = await showDialog<_GroupSelectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GroupSelectionDialog(files: files),
    );

    if (result == null || !mounted) {
      _isProcessingShare = false;
      return;
    }

    // Navigate to the group
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocGroupDetailScreen(groupId: result.groupId),
      ),
    );

    // Process files - track which files we've already processed
    final processedPaths = <String>{};
    final notifier = ref.read(docDocumentNotifierProvider.notifier);
    int successCount = 0;

    for (final file in files) {
      if (file.path.isNotEmpty && !processedPaths.contains(file.path)) {
        processedPaths.add(file.path); // Mark as processed
        try {
          final fileObj = File(file.path);
          if (await fileObj.exists()) {
            await notifier.addDocument(
              groupId: result.groupId,
              name: file.path.split('/').last,
              file: fileObj,
              mimeType: _getMimeType(file.path),
            );
            successCount++;
          }
        } catch (e) {
          debugPrint('Error adding file: $e');
        }
      } else if (processedPaths.contains(file.path)) {
        debugPrint('Skipping duplicate file: ${file.path}');
      }
    }

    _isProcessingShare = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount file${successCount != 1 ? 's' : ''} added to ${result.groupName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _showWrongShareTypeDialog({
    required String title,
    required String message,
    required String correctDestination,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Color(0xFFA6ADBD))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
            child: Text(correctDestination),
          ),
        ],
      ),
    ) ?? false;
  }

  String? _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        return null;
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildNavigator(0, const DashboardScreen()),
              _buildNavigator(1, const DiscoverScreen()),
              _buildNavigator(2, const SettingsScreen()),
            ],
          ),
          const PersistentVoiceOverlay(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E38), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_outlined),
              activeIcon: Icon(Icons.apps),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigator(int index, Widget screen) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => screen,
          settings: settings,
        );
      },
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2029),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF4ECDC4)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5A5A6A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF5A5A6A), size: 16),
          ],
        ),
      ),
    );
  }
}

class _GroupSelectionResult {
  final String groupId;
  final String groupName;

  _GroupSelectionResult({required this.groupId, required this.groupName});
}

class _GroupSelectionDialog extends ConsumerStatefulWidget {
  final List<SharedMediaFile> files;

  const _GroupSelectionDialog({required this.files});

  @override
  ConsumerState<_GroupSelectionDialog> createState() => _GroupSelectionDialogState();
}

class _GroupSelectionDialogState extends ConsumerState<_GroupSelectionDialog> {
  String? _selectedGroupId;
  bool _isCreatingNew = false;
  final _newGroupNameController = TextEditingController();
  final _newGroupDescController = TextEditingController();

  @override
  void dispose() {
    _newGroupNameController.dispose();
    _newGroupDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(docGroupsProvider);

    return Dialog(
      backgroundColor: const Color(0xFF16181F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E2029))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_outlined, color: Color(0xFF4ECDC4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Group',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.files.length} file${widget.files.length > 1 ? 's' : ''} to upload',
                          style: const TextStyle(
                            color: Color(0xFF5A5A6A),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isCreatingNew)
              _buildCreateGroupForm()
            else
              Expanded(
                child: groupsAsync.when(
                  data: (groups) => _buildGroupList(groups),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                  ),
                  error: (_, __) => const Center(
                    child: Text('Error loading groups', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            if (!_isCreatingNew)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1E2029))),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedGroupId == null
                            ? null
                            : () {
                                final selectedGroup = groupsAsync.value?.firstWhere(
                                  (g) => g.id == _selectedGroupId,
                                );
                                if (selectedGroup != null) {
                                  Navigator.pop(
                                    context,
                                    _GroupSelectionResult(
                                      groupId: selectedGroup.id,
                                      groupName: selectedGroup.name,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Upload to Selected Group'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _isCreatingNew = true),
                      icon: const Icon(Icons.add, color: Color(0xFF4ECDC4)),
                      label: const Text(
                        'Create New Group',
                        style: TextStyle(color: Color(0xFF4ECDC4)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(List<DocGroup> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_outlined, size: 48, color: Color(0xFF2A2C38)),
            const SizedBox(height: 16),
            const Text(
              'No groups yet',
              style: TextStyle(color: Color(0xFF5A5A6A)),
            ),
            TextButton(
              onPressed: () => setState(() => _isCreatingNew = true),
              child: const Text('Create your first group'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isSelected = _selectedGroupId == group.id;

        return RadioListTile<String>(
          value: group.id,
          groupValue: _selectedGroupId,
          onChanged: (value) => setState(() => _selectedGroupId = value),
          title: Text(
            group.name,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4ECDC4) : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${group.documentIds.length} documents',
            style: const TextStyle(color: Color(0xFF5A5A6A), fontSize: 12),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4ECDC4).withOpacity(0.2)
                  : const Color(0xFF1E2029),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.folder,
              color: isSelected ? const Color(0xFF4ECDC4) : const Color(0xFF5A5A6A),
            ),
          ),
          activeColor: const Color(0xFF4ECDC4),
          tileColor: isSelected ? const Color(0xFF4ECDC4).withOpacity(0.1) : null,
        );
      },
    );
  }

  Widget _buildCreateGroupForm() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _newGroupNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(color: Color(0xFF5A5A6A)),
                filled: true,
                fillColor: Color(0xFF1E2029),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newGroupDescController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: TextStyle(color: Color(0xFF5A5A6A)),
                filled: true,
                fillColor: Color(0xFF1E2029),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _isCreatingNew = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Create & Upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createGroup() async {
    final name = _newGroupNameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(docGroupNotifierProvider.notifier);
    final group = await notifier.createGroup(
      name,
      description: _newGroupDescController.text.trim(),
    );

    if (group != null && mounted) {
      Navigator.pop(
        context,
        _GroupSelectionResult(groupId: group.id, groupName: group.name),
      );
    }
  }
}
