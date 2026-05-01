import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/doc_provider.dart';
import '../../services/doc_repository.dart';
import '../../models/doc_group.dart';
import '../../models/doc_document.dart';
import 'document_viewer_screen.dart';

class DocGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const DocGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<DocGroupDetailScreen> createState() => _DocGroupDetailScreenState();
}

class _DocGroupDetailScreenState extends ConsumerState<DocGroupDetailScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadDocument() async {
    final notifier = ref.read(docDocumentNotifierProvider.notifier);
    await notifier.pickAndAddDocument(widget.groupId);
  }

  Future<void> _openDocument(DocDocument document) async {
    final ext = document.fileExtension.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    final isPdf = ext == 'pdf';

    if (isImage || isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(document: document),
        ),
      );
    } else {
      final result = await OpenFilex.open(document.filePath);
      if (result.message != 'done' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    }
  }

  void _showRenameDialog(DocDocument document) {
    final nameController = TextEditingController(text: document.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: const Text('Rename File', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'File name',
            hintStyle: TextStyle(color: Color(0xFF5A5A6A)),
            filled: true,
            fillColor: Color(0xFF1E2029),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final notifier = ref.read(docDocumentNotifierProvider.notifier);
                await notifier.renameDocument(
                  document.id,
                  name,
                  groupId: widget.groupId,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ref.invalidate(docDocumentsProvider(widget.groupId));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _showMoveCopyDialog(DocDocument document, {required bool isMove}) {
    showDialog(
      context: context,
      builder: (context) => _MoveCopyDialog(
        document: document,
        currentGroupId: widget.groupId,
        isMove: isMove,
      ),
    );
  }

  void _shareDocument(DocDocument document) async {
    try {
      final file = File(document.filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(document.filePath)],
          text: document.name,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(DocDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: const Text('Delete Document', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${document.name}"?',
          style: const TextStyle(color: Color(0xFFA6ADBD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final notifier = ref.read(docDocumentNotifierProvider.notifier);
              await notifier.deleteDocument(document.id, widget.groupId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showDocumentOptions(DocDocument document) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2C38),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF4ECDC4)),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(document);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline, color: Color(0xFF4ECDC4)),
              title: const Text('Move to Group', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showMoveCopyDialog(document, isMove: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF4ECDC4)),
              title: const Text('Copy to Group', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showMoveCopyDialog(document, isMove: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF4ECDC4)),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareDocument(document);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
              title: const Text('Delete', style: TextStyle(color: Color(0xFFFF5252))),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(document);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(docGroupByIdProvider(widget.groupId));
    final documentsAsync = ref.watch(docDocumentsProvider(widget.groupId));
    final searchQuery = _searchController.text;
    final searchResults = searchQuery.isNotEmpty
        ? ref.watch(docDocumentSearchProvider(searchQuery))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: groupAsync.when(
                      data: (group) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group?.name ?? 'Unknown',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            '${group?.documentIds.length ?? 0} documents',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5A5A6A),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const Text('Error', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  IconButton(
                    onPressed: _pickAndUploadDocument,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.upload_file,
                        color: Color(0xFF4ECDC4),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16181F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2029)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    hintStyle: const TextStyle(color: Color(0xFF5A5A6A)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF5A5A6A)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF5A5A6A)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Documents List
            Expanded(
              child: searchQuery.isNotEmpty
                  ? _buildSearchResults(searchResults)
                  : _buildDocumentsList(documentsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList(AsyncValue<List<DocDocument>> documentsAsync) {
    return documentsAsync.when(
      data: (documents) {
        if (documents.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final doc = documents[index];
            return _DocumentCard(
              document: doc,
              onTap: () => _openDocument(doc),
              onOptions: () => _showDocumentOptions(doc),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Color(0xFFFF5252)),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<DocDocument>>? searchResults) {
    if (searchResults == null) return const SizedBox.shrink();

    return searchResults.when(
      data: (documents) {
        if (documents.isEmpty) {
          return const Center(
            child: Text(
              'No documents found',
              style: TextStyle(color: Color(0xFF5A5A6A)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final doc = documents[index];
            return _DocumentCard(
              document: doc,
              onTap: () => _openDocument(doc),
              onOptions: () => _showDocumentOptions(doc),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2029),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.upload_file,
              size: 48,
              color: Color(0xFF2A2C38),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Documents Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your first document to this group',
            style: TextStyle(
              color: Color(0xFF5A5A6A),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAndUploadDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocDocument document;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onOptions,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16181F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2029)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                document.icon,
                color: const Color(0xFF4ECDC4),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${document.displaySize} • ${document.fileExtension.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF5A5A6A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOptions,
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF5A5A6A),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveCopyDialog extends ConsumerStatefulWidget {
  final DocDocument document;
  final String currentGroupId;
  final bool isMove;

  const _MoveCopyDialog({
    required this.document,
    required this.currentGroupId,
    required this.isMove,
  });

  @override
  ConsumerState<_MoveCopyDialog> createState() => _MoveCopyDialogState();
}

class _MoveCopyDialogState extends ConsumerState<_MoveCopyDialog> {
  String? _selectedGroupId;

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
                    child: Icon(
                      widget.isMove ? Icons.drive_file_move_outlined : Icons.copy,
                      color: const Color(0xFF4ECDC4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isMove ? 'Move to Group' : 'Copy to Group',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.document.name,
                          style: const TextStyle(
                            color: Color(0xFF5A5A6A),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  final availableGroups = groups
                      .where((g) => g.id != widget.currentGroupId)
                      .toList();

                  if (availableGroups.isEmpty) {
                    return const Center(
                      child: Text(
                        'No other groups available',
                        style: TextStyle(color: Color(0xFF5A5A6A)),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: availableGroups.length,
                    itemBuilder: (context, index) {
                      final group = availableGroups[index];
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
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                ),
                error: (_, __) => const Center(
                  child: Text('Error loading groups', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E2029))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedGroupId == null
                          ? null
                          : () => _executeMoveOrCopy(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(widget.isMove ? 'Move' : 'Copy'),
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

  void _executeMoveOrCopy() async {
    if (_selectedGroupId == null) return;

    final notifier = ref.read(docDocumentNotifierProvider.notifier);

    if (widget.isMove) {
      await notifier.moveDocumentToGroup(
        widget.document.id,
        widget.currentGroupId,
        _selectedGroupId!,
      );
    } else {
      await notifier.copyDocumentToGroup(
        widget.document.id,
        widget.currentGroupId,
        _selectedGroupId!,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isMove
                ? 'Moved to new group'
                : 'Copied to new group',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Provider for single group lookup
final docGroupByIdProvider = FutureProvider.family<DocGroup?, String>((ref, groupId) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getGroupById(groupId);
});
