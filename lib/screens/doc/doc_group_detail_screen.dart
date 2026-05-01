import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/doc_provider.dart';
import '../../services/doc_repository.dart';

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

  Future<void> _openDocument(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.message != 'done' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  void _showDeleteConfirmation(dynamic document) {
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

  Widget _buildDocumentsList(AsyncValue<List<dynamic>> documentsAsync) {
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
              onTap: () => _openDocument(doc.filePath),
              onDelete: () => _showDeleteConfirmation(doc),
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

  Widget _buildSearchResults(AsyncValue<List<dynamic>>? searchResults) {
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
              onTap: () => _openDocument(doc.filePath),
              onDelete: () => _showDeleteConfirmation(doc),
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
  final dynamic document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
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

// Provider for single group lookup
final docGroupByIdProvider = FutureProvider.family<dynamic, String>((ref, groupId) async {
  final repository = ref.watch(docRepositoryProvider);
  return await repository.getGroupById(groupId);
});
