import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/doc_provider.dart';
import '../../models/doc_group.dart';
import '../../widgets/voice_button.dart';
import 'doc_group_detail_screen.dart';
import 'doc_create_group_screen.dart';

class DocHomeScreen extends ConsumerStatefulWidget {
  const DocHomeScreen({super.key});

  @override
  ConsumerState<DocHomeScreen> createState() => _DocHomeScreenState();
}

class _DocHomeScreenState extends ConsumerState<DocHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const DocCreateGroupScreen(),
    );
  }

  void _showRenameGroupDialog(DocGroup group) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: const Text('Rename Group', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
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
              controller: descController,
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
          ],
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
                final notifier = ref.read(docGroupNotifierProvider.notifier);
                await notifier.renameGroup(
                  group.id,
                  name,
                  newDescription: descController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ref.invalidate(docGroupsProvider);
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupConfirmation(DocGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181F),
        title: const Text('Delete Group', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This will also delete all ${group.documentIds.length} document(s) inside.',
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
              final notifier = ref.read(docGroupNotifierProvider.notifier);
              await notifier.deleteGroup(group.id);
              ref.invalidate(docGroupsProvider);
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
    final groupsAsync = ref.watch(docGroupsProvider);
    final searchQuery = _searchController.text;
    final searchResults = searchQuery.isNotEmpty
        ? ref.watch(docGroupSearchProvider(searchQuery))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: SafeArea(
        child: Column(
          children: [
            // Header with voice button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF44B09E)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documents',
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Organize your files in groups',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5A5A6A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VoiceButton(),
                  IconButton(
                    onPressed: _showCreateGroupDialog,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
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
                    hintText: 'Search groups...',
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

            // Groups List
            Expanded(
              child: searchQuery.isNotEmpty
                  ? _buildSearchResults(searchResults)
                  : _buildGroupsList(groupsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(AsyncValue<List<dynamic>> groupsAsync) {
    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupCard(
              group: group,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocGroupDetailScreen(groupId: group.id),
                ),
              ),
              onRename: () => _showRenameGroupDialog(group),
              onDelete: () => _showDeleteGroupConfirmation(group),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error loading groups: $error',
          style: const TextStyle(color: Color(0xFFFF5252)),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<dynamic>>? searchResults) {
    if (searchResults == null) return const SizedBox.shrink();

    return searchResults.when(
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'No groups found',
              style: TextStyle(color: Color(0xFF5A5A6A)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupCard(
              group: group,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocGroupDetailScreen(groupId: group.id),
                ),
              ),
              onRename: () => _showRenameGroupDialog(group),
              onDelete: () => _showDeleteGroupConfirmation(group),
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
              Icons.folder_outlined,
              size: 64,
              color: Color(0xFF2A2C38),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Groups Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a group to start organizing\nyour documents',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF5A5A6A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
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

class _GroupCard extends StatelessWidget {
  final dynamic group;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  void _showOptionsMenu(BuildContext context) {
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
                onRename();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
              title: const Text('Delete', style: TextStyle(color: Color(0xFFFF5252))),
              onTap: () {
                Navigator.pop(context);
                onDelete();
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showOptionsMenu(context),
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
              child: const Icon(
                Icons.folder,
                color: Color(0xFF4ECDC4),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (group.description != null && group.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.description!,
                      style: const TextStyle(
                        color: Color(0xFF5A5A6A),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${group.documentIds.length} documents',
                    style: const TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showOptionsMenu(context),
              icon: const Icon(Icons.more_vert, color: Color(0xFF5A5A6A)),
            ),
          ],
        ),
      ),
    );
  }

}
