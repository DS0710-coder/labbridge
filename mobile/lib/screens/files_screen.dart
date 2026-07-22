import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/folder.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';
import '../services/transfer_service.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
import 'files_batch_mixin.dart';
import '../main.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> with FilesBatchMixin<FilesScreen> {
  final DbService _dbService = DbService();
  static const _uuid = Uuid();
  StreamSubscription<String>? _completionSub;

  List<Folder> _folders = [];
  List<FileItem> _files = [];
  List<Folder> _breadcrumbs = [];
  String? _currentFolderId;
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'All';

  final List<String> _tabs = ['All', 'Documents', 'Images', 'Media', 'Archives', 'Code'];

  @override
  Set<String> get selectedFolderIds => _selectedFolderIds;
  @override
  Set<String> get selectedFileIds => _selectedFileIds;
  @override
  String? get currentFolderId => _currentFolderId;
  @override
  List<Folder> get breadcrumbs => _breadcrumbs;
  @override
  List<FileItem> get files => _files;
  @override
  DbService get dbService => _dbService;
  @override
  Uuid get uuid => _uuid;
  @override
  void loadFolder(String? folderId) => _loadFolder(folderId);

  bool _selectionMode = false;
  final Set<String> _selectedFolderIds = {};
  final Set<String> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _loadFolder(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final transferService = Provider.of<TransferService>(context, listen: false);
      _completionSub = transferService.completions.listen((_) {
        if (mounted) _loadFolder(_currentFolderId);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _completionSub?.cancel();
    super.dispose();
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
        _selectedFolderIds.clear();
        _selectedFileIds.clear();
        _selectionMode = false;
      });
    }
  }

  void _navigateToFolder(String? folderId) {
    _loadFolder(folderId);
  }

  String _sanitizeFolderName(String raw) {
    var clean = raw.trim().replaceAll(RegExp(r'[\\/]+'), '');
    if (clean.isEmpty || clean == '.' || clean == '..') clean = 'Folder';
    if (clean.length > 100) clean = clean.substring(0, 100);
    return clean;
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text(
          'New Folder',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            counterStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            filled: true,
            fillColor: AppTheme.surface2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (name != null) {
      final cleanName = _sanitizeFolderName(name);
      if (cleanName.isNotEmpty) {
        final folder = Folder(
          id: _uuid.v4(),
          name: cleanName,
          parentId: _currentFolderId,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _dbService.insertFolder(folder);
        _loadFolder(_currentFolderId);
      }
    }
  }

  void _showFolderOptions(Folder folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildSheetOption(
              Icons.checklist_rounded,
              'Select',
              () {
                Navigator.pop(context);
                setState(() {
                  _selectionMode = true;
                  _selectedFolderIds.add(folder.id);
                });
              },
            ),
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text('Rename Folder', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            filled: true,
            fillColor: AppTheme.surface2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (name != null) {
      final cleanName = _sanitizeFolderName(name);
      if (cleanName.isNotEmpty) {
        await _dbService.updateFolder(folder.copyWith(name: cleanName));
        _loadFolder(_currentFolderId);
      }
    }
  }

  void _showColorPicker(Folder folder) {
    final colors = [
      '#6C63FF', '#22C55E', '#EF4444', '#F97316',
      '#3B82F6', '#A855F7', '#EC4899', '#F59E0B',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text('Delete Folder?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${folder.name}"? Sub-folders will be moved up.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await _dbService.deleteFolder(folder.id);
      _loadFolder(_currentFolderId);
    }
  }

  void _showFileOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _buildSheetOption(
              Icons.checklist_rounded,
              'Select',
              () {
                Navigator.pop(context);
                setState(() {
                  _selectionMode = true;
                  _selectedFileIds.add(file.id);
                });
              },
            ),
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text('Move to Folder', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppTheme.textSecondary),
                title: const Text('Root', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(context, '__root__'),
              ),
              ...allFolders.map((f) => ListTile(
                    leading: Icon(
                      Icons.folder_rounded,
                      color: Color(
                        int.parse('FF${f.color.replaceAll('#', '')}', radix: 16),
                      ),
                    ),
                    title: Text(f.name, style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () => Navigator.pop(context, f.id),
                  )),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text('Edit Tags', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Comma-separated tags',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            filled: true,
            fillColor: AppTheme.surface2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (tags != null) {
      await _dbService.updateFile(file.copyWith(tags: tags));
      _loadFolder(_currentFolderId);
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E2E)),
        ),
        title: const Text('Delete File?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${file.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      await _dbService.deleteFile(file.id);
      _loadFolder(_currentFolderId);
    }
  }

  void _toggleFolderSelection(Folder folder) {
    setState(() {
      if (_selectedFolderIds.contains(folder.id)) {
        _selectedFolderIds.remove(folder.id);
      } else {
        _selectedFolderIds.add(folder.id);
      }
      if (_selectedFolderIds.isEmpty && _selectedFileIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _toggleFileSelection(FileItem file) {
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
      } else {
        _selectedFileIds.add(file.id);
      }
      if (_selectedFolderIds.isEmpty && _selectedFileIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      final filteredList = _getFilteredFiles();
      final filteredFolderList = _getFilteredFolders();
      if (_selectedFolderIds.length + _selectedFileIds.length == filteredFolderList.length + filteredList.length) {
        _selectedFolderIds.clear();
        _selectedFileIds.clear();
        _selectionMode = false;
      } else {
        _selectedFolderIds.addAll(filteredFolderList.map((f) => f.id));
        _selectedFileIds.addAll(filteredList.map((f) => f.id));
      }
    });
  }

  bool _matchesTab(FileItem file) {
    if (_selectedTab == 'All') return true;
    final ext = file.name.split('.').last.toLowerCase();
    switch (_selectedTab) {
      case 'Documents':
        return ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext);
      case 'Images':
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      case 'Media':
        return ['mp4', 'avi', 'mkv', 'mov', 'mp3', 'wav', 'flac'].contains(ext);
      case 'Archives':
        return ['zip', 'rar', 'tar', 'gz'].contains(ext);
      case 'Code':
        return ['py', 'js', 'dart', 'java', 'c', 'cpp', 'html', 'css', 'ts', 'json'].contains(ext);
      default:
        return true;
    }
  }

  List<Folder> _getFilteredFolders() {
    if (_selectedTab != 'All' && _searchQuery.isEmpty) return [];
    if (_searchQuery.isEmpty) return _folders;
    return _folders.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<FileItem> _getFilteredFiles() {
    var result = _files.where(_matchesTab).toList();
    if (_searchQuery.isNotEmpty) {
      result = result.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return result;
  }

  Widget _buildSheetOption(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textPrimary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBatchActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E1E2E)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? AppTheme.accent, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFolders = _getFilteredFolders();
    final filteredFiles = _getFilteredFiles();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: !_selectionMode
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(colors: AppTheme.gradPrimary),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _showCreateFolderDialog,
                child: const Icon(Icons.create_new_folder_rounded, color: Colors.white, size: 26),
              ),
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack)
          : null,
      bottomNavigationBar: _selectionMode && (_selectedFolderIds.isNotEmpty || _selectedFileIds.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: Color(0xFF1E1E28))),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBatchActionButton(
                      icon: Icons.folder_shared_rounded,
                      label: 'Move / Shift',
                      onTap: batchMoveSelected,
                    ),
                    _buildBatchActionButton(
                      icon: Icons.unarchive_rounded,
                      label: 'Extract',
                      onTap: batchExtractSelected,
                    ),
                    _buildBatchActionButton(
                      icon: Icons.delete_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onTap: batchDeleteSelected,
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 250.ms)
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: !_selectionMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Files',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        if (_folders.isNotEmpty || _files.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.checklist_rounded, color: AppTheme.accent, size: 26),
                            tooltip: 'Select multiple items',
                            onPressed: () {
                              setState(() {
                                _selectionMode = true;
                              });
                            },
                          ),
                      ],
                    ).animate().fadeIn()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
                              onPressed: () {
                                setState(() {
                                  _selectionMode = false;
                                  _selectedFolderIds.clear();
                                  _selectedFileIds.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedFolderIds.length + _selectedFileIds.length} Selected',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _selectAll,
                          icon: const Icon(Icons.select_all_rounded, color: AppTheme.accent, size: 20),
                          label: Text(
                            _selectedFolderIds.length + _selectedFileIds.length == filteredFolders.length + filteredFiles.length
                                ? 'Deselect all'
                                : 'Select all',
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(),
            ),

            // Search Bar at top (#111118 input with #1E1E28 border, search icon, filter icon)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E1E28)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search files and folders...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                      )
                    else
                      const Icon(Icons.tune_rounded, color: AppTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 14),

            // Filter chips row below search: [All] [Documents] [Images] [Media] [Archives] [Code] — animated pill selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTab == tab;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = tab;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : const Color(0xFF1E1E28),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ).animate(delay: (30 * idx).ms).fadeIn().slideX(begin: 0.1, end: 0);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Breadcrumb trail with subtle background #111118, rounded 12px pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E1E28)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToFolder(null),
                        child: Row(
                          children: [
                            Icon(
                              Icons.home_rounded,
                              size: 16,
                              color: _currentFolderId == null ? AppTheme.accent : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Root',
                              style: TextStyle(
                                color: _currentFolderId == null ? AppTheme.accent : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                                color: AppTheme.textMuted,
                                size: 16,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _navigateToFolder(crumb.id),
                              child: Text(
                                crumb.name,
                                style: TextStyle(
                                  color: isLast ? AppTheme.accent : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : (filteredFolders.isEmpty && filteredFiles.isEmpty)
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(colors: AppTheme.borderGrad),
                            ),
                            padding: const EdgeInsets.all(1.5),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(22.5),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.folder_open_rounded,
                                      color: AppTheme.accent,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _searchQuery.isNotEmpty || _selectedTab != 'All'
                                        ? 'No matching files'
                                        : 'Empty folder',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty || _selectedTab != 'All'
                                        ? 'Try checking other categories or adjusting search terms'
                                        : 'Create a folder or transfer files from PC',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                        )
                      : RefreshIndicator(
                          color: AppTheme.accent,
                          backgroundColor: AppTheme.surface,
                          onRefresh: () => _loadFolder(_currentFolderId),
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 100),
                            children: [
                              ...filteredFolders.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final folder = entry.value;
                                return FolderTile(
                                  folder: folder,
                                  isSelected: _selectedFolderIds.contains(folder.id),
                                  selectionMode: _selectionMode,
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleFolderSelection(folder);
                                    } else {
                                      _navigateToFolder(folder.id);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_selectionMode) {
                                      _showFolderOptions(folder);
                                    } else {
                                      _toggleFolderSelection(folder);
                                    }
                                  },
                                ).animate(delay: (40 * idx).ms).fadeIn().slideY(begin: 0.05);
                              }),
                              if (filteredFolders.isNotEmpty && filteredFiles.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Divider(color: Color(0xFF1E1E2E), height: 1),
                                ),
                              ...filteredFiles.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final file = entry.value;
                                return FileTile(
                                  file: file,
                                  isSelected: _selectedFileIds.contains(file.id),
                                  selectionMode: _selectionMode,
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleFileSelection(file);
                                    } else {
                                      OpenFile.open(file.localPath);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_selectionMode) {
                                      _showFileOptions(file);
                                    } else {
                                      _toggleFileSelection(file);
                                    }
                                  },
                                ).animate(delay: (40 * (idx + filteredFolders.length)).ms).fadeIn().slideY(begin: 0.05);
                              }),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
