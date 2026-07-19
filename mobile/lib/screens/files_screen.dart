import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/folder.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final DbService _dbService = DbService();
  static const _uuid = Uuid();

  List<Folder> _folders = [];
  List<FileItem> _files = [];
  List<Folder> _breadcrumbs = [];
  String? _currentFolderId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolder(null);
  }

  Future<void> _loadFolder(String? folderId) async {
    setState(() => _loading = true);

    final folders = await _dbService.getChildFolders(folderId);
    final files = await _dbService.getFilesInFolder(folderId);

    // Build breadcrumbs
    final crumbs = <Folder>[];
    String? id = folderId;
    while (id != null) {
      final folder = await _dbService.getFolder(id);
      if (folder != null) {
        crumbs.insert(0, folder);
        id = folder.parentId;
      } else {
        break;
      }
    }

    if (mounted) {
      setState(() {
        _currentFolderId = folderId;
        _folders = folders;
        _files = files;
        _breadcrumbs = crumbs;
        _loading = false;
      });
    }
  }

  void _navigateToFolder(String? folderId) {
    _loadFolder(folderId);
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Folder',
          style: TextStyle(color: Color(0xFFE8E8F0)),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE8E8F0)),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final folder = Folder(
        id: _uuid.v4(),
        name: name,
        parentId: _currentFolderId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _dbService.insertFolder(folder);
      _loadFolder(_currentFolderId);
    }
  }

  void _showFolderOptions(Folder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              folder.name,
              style: const TextStyle(
                color: Color(0xFFE8E8F0),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildSheetOption(
              Icons.edit_rounded,
              'Rename',
              () {
                Navigator.pop(context);
                _showRenameFolderDialog(folder);
              },
            ),
            _buildSheetOption(
              Icons.palette_rounded,
              'Change Color',
              () {
                Navigator.pop(context);
                _showColorPicker(folder);
              },
            ),
            _buildSheetOption(
              Icons.delete_rounded,
              'Delete',
              () {
                Navigator.pop(context);
                _deleteFolder(folder);
              },
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameFolderDialog(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Folder', style: TextStyle(color: Color(0xFFE8E8F0))),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE8E8F0)),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _dbService.updateFolder(folder.copyWith(name: name));
      _loadFolder(_currentFolderId);
    }
  }

  void _showColorPicker(Folder folder) {
    final colors = [
      '#6C63FF', '#22C55E', '#EF4444', '#F97316',
      '#3B82F6', '#A855F7', '#EC4899', '#F59E0B',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Color',
                style: TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: colors.map((hex) {
                  final colorVal = Color(
                    int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                  );
                  final isSelected = folder.color == hex;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _dbService.updateFolder(folder.copyWith(color: hex));
                      _loadFolder(_currentFolderId);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder?', style: TextStyle(color: Color(0xFFE8E8F0))),
        content: Text(
          'Delete "${folder.name}"? Sub-folders will be moved up.',
          style: const TextStyle(color: Color(0xFF6B6B80)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteFolder(folder.id);
      _loadFolder(_currentFolderId);
    }
  }

  void _showFileOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              file.name,
              style: const TextStyle(
                color: Color(0xFFE8E8F0),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _buildSheetOption(
              Icons.open_in_new_rounded,
              'Open',
              () {
                Navigator.pop(context);
                OpenFile.open(file.localPath);
              },
            ),
            _buildSheetOption(
              Icons.share_rounded,
              'Share',
              () {
                Navigator.pop(context);
                SharePlus.instance.share(ShareParams(files: [XFile(file.localPath)]));
              },
            ),
            _buildSheetOption(
              Icons.drive_file_move_rounded,
              'Move to Folder',
              () {
                Navigator.pop(context);
                _showMoveFolderPicker(file);
              },
            ),
            _buildSheetOption(
              Icons.label_rounded,
              'Edit Tags',
              () {
                Navigator.pop(context);
                _showEditTagsDialog(file);
              },
            ),
            _buildSheetOption(
              Icons.delete_rounded,
              'Delete',
              () {
                Navigator.pop(context);
                _deleteFile(file);
              },
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveFolderPicker(FileItem file) async {
    final allFolders = await _dbService.getAllFolders();
    if (!mounted) return;

    final selectedId = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Move to Folder', style: TextStyle(color: Color(0xFFE8E8F0))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_rounded, color: Color(0xFF6B6B80)),
                title: const Text('Root', style: TextStyle(color: Color(0xFFE8E8F0))),
                onTap: () => Navigator.pop(context, '__root__'),
              ),
              ...allFolders.map((f) => ListTile(
                    leading: Icon(
                      Icons.folder_rounded,
                      color: Color(
                        int.parse('FF${f.color.replaceAll('#', '')}', radix: 16),
                      ),
                    ),
                    title: Text(f.name, style: const TextStyle(color: Color(0xFFE8E8F0))),
                    onTap: () => Navigator.pop(context, f.id),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selectedId != null) {
      final newFolderId = selectedId == '__root__' ? null : selectedId;
      await _dbService.updateFile(
        newFolderId == null
            ? file.copyWith(clearFolderId: true)
            : file.copyWith(folderId: newFolderId),
      );
      _loadFolder(_currentFolderId);
    }
  }

  Future<void> _showEditTagsDialog(FileItem file) async {
    final controller = TextEditingController(text: file.tags);
    final tags = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Tags', style: TextStyle(color: Color(0xFFE8E8F0))),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFFE8E8F0)),
          decoration: InputDecoration(
            hintText: 'Comma-separated tags',
            hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );

    if (tags != null) {
      await _dbService.updateFile(file.copyWith(tags: tags));
      _loadFolder(_currentFolderId);
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111118),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File?', style: TextStyle(color: Color(0xFFE8E8F0))),
        content: Text(
          'Delete "${file.name}"?',
          style: const TextStyle(color: Color(0xFF6B6B80)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteFile(file.id);
      _loadFolder(_currentFolderId);
    }
  }

  Widget _buildSheetOption(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFFE8E8F0), size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFFE8E8F0),
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: _showCreateFolderDialog,
        child: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Files',
                style: TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Breadcrumbs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToFolder(null),
                    child: Text(
                      'Root',
                      style: TextStyle(
                        color: _currentFolderId == null
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF6B6B80),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ..._breadcrumbs.map((crumb) {
                    final isLast = crumb == _breadcrumbs.last;
                    return Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF6B6B80),
                            size: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _navigateToFolder(crumb.id),
                          child: Text(
                            crumb.name,
                            style: TextStyle(
                              color: isLast
                                  ? const Color(0xFF6C63FF)
                                  : const Color(0xFF6B6B80),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    )
                  : (_folders.isEmpty && _files.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                color: const Color(0xFF6B6B80).withValues(alpha: 0.5),
                                size: 56,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Empty folder',
                                style: TextStyle(
                                  color: Color(0xFF6B6B80),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                            ..._folders.map((folder) => FolderTile(
                                  folder: folder,
                                  onTap: () => _navigateToFolder(folder.id),
                                  onLongPress: () => _showFolderOptions(folder),
                                )),
                            if (_folders.isNotEmpty && _files.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: Divider(color: Color(0xFF1E1E2E), height: 1),
                              ),
                            ..._files.map((file) => FileTile(
                                  file: file,
                                  onTap: () => OpenFile.open(file.localPath),
                                  onLongPress: () => _showFileOptions(file),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
