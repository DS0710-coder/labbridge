import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/folder.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
import '../main.dart';
import 'files_batch_mixin.dart';

class FilesScreen extends StatefulWidget {
  final String? initialFolderId;

  const FilesScreen({super.key, this.initialFolderId});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen>
    with FilesBatchMixin<FilesScreen> {
  final DbService _dbService = DbService();
  final Uuid _uuid = const Uuid();

  String? _currentFolderId;
  List<Folder> _folders = [];
  List<FileItem> _files = [];
  List<Folder> _breadcrumbs = [];
  bool _loading = true;

  final Set<String> _selectedFolderIds = {};
  final Set<String> _selectedFileIds = {};
  bool _selectionMode = false;

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

  @override
  void initState() {
    super.initState();
    _currentFolderId = widget.initialFolderId;
    _loadFolder(_currentFolderId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFolder(String? folderId) async {
    setState(() => _loading = true);

    final folders = await _dbService.getChildFolders(folderId);
    final files = await _dbService.getFilesInFolder(folderId);

    List<Folder> crumbs = [];
    Set<String> visited = {};
    String? cid = folderId;
    while (cid != null) {
      if (visited.contains(cid)) break;
      visited.add(cid);
      final f = await _dbService.getFolder(cid);
      if (f != null) {
        crumbs.insert(0, f);
        cid = f.parentId;
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
    if (clean.isEmpty || clean == '.' || clean == '..') clean = 'DIR';
    if (clean.length > 100) clean = clean.substring(0, 100);
    return clean;
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text(
          'NEW DIRECTORY',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'DIRECTORY NAME',
            hintStyle: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'),
            counterStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'monospace'),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            filled: true,
            fillColor: Color(0xFF121214),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CREATE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    controller.dispose();
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
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF27272A))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                color: const Color(0xFF27272A),
              ),
              Text(
                '/${folder.name.toUpperCase()}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              _buildSheetOption(
                Icons.check_box_outlined,
                'SELECT DIRECTORY',
                () {
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = true;
                    _selectedFolderIds.add(folder.id);
                  });
                },
              ),
              _buildSheetOption(
                Icons.edit_outlined,
                'RENAME DIRECTORY',
                () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(folder);
                },
              ),
              _buildSheetOption(
                Icons.palette_outlined,
                'CHANGE COLOR TAG',
                () {
                  Navigator.pop(context);
                  _showColorPicker(folder);
                },
              ),
              _buildSheetOption(
                Icons.delete_outline,
                'DELETE DIRECTORY',
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
      ),
    );
  }

  Future<void> _showRenameFolderDialog(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text('RENAME DIRECTORY', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            counterStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'monospace'),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            filled: true,
            fillColor: Color(0xFF121214),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('RENAME', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    controller.dispose();
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
      '#FFFFFF', '#A1A1AA', '#71717A', '#52525B',
      '#3F3F46', '#27272A', '#18181B', '#09090B',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF27272A))),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHOOSE MONOCHROME TAG',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorVal,
                        border: Border.all(
                          color: isSelected ? Colors.white : const Color(0xFF3F3F46),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: hex == '#FFFFFF' ? Colors.black : Colors.white, size: 20)
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
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text('DELETE DIRECTORY?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: Text(
          'Delete "/${folder.name.toUpperCase()}"? Sub-directories will be unlinked.',
          style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF27272A))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                color: const Color(0xFF27272A),
              ),
              Text(
                file.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildSheetOption(
                Icons.check_box_outlined,
                'SELECT FILE',
                () {
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = true;
                    _selectedFileIds.add(file.id);
                  });
                },
              ),
              _buildSheetOption(
                Icons.open_in_new,
                'OPEN FILE',
                () {
                  Navigator.pop(context);
                  OpenFile.open(file.localPath);
                },
              ),
              _buildSheetOption(
                Icons.share_outlined,
                'SHARE FILE',
                () {
                  Navigator.pop(context);
                  SharePlus.instance.share(ShareParams(files: [XFile(file.localPath)]));
                },
              ),
              _buildSheetOption(
                Icons.drive_file_move_outlined,
                'MOVE TO DIRECTORY',
                () {
                  Navigator.pop(context);
                  _showMoveFolderPicker(file);
                },
              ),
              _buildSheetOption(
                Icons.tag,
                'EDIT TAGS',
                () {
                  Navigator.pop(context);
                  _showEditTagsDialog(file);
                },
              ),
              _buildSheetOption(
                Icons.delete_outline,
                'DELETE FILE',
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
      ),
    );
  }

  Future<void> _showMoveFolderPicker(FileItem file) async {
    final allFolders = await _dbService.getAllFolders();
    if (!mounted) return;

    final selectedId = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text('MOVE TO DIRECTORY', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: Colors.white, size: 18),
                title: const Text('/ROOT', style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, '__root__'),
              ),
              ...allFolders.map((f) => ListTile(
                    leading: const Icon(
                      Icons.folder_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    title: Text('/${f.name.toUpperCase()}', style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace')),
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
        backgroundColor: const Color(0xFF09090B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text('EDIT TAGS', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'comma, separated, tags',
            hintStyle: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            filled: true,
            fillColor: Color(0xFF121214),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('SAVE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    controller.dispose();
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
        backgroundColor: const Color(0xFF09090B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text('DELETE FILE?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: Text(
          'Delete "${file.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
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
      leading: Icon(icon, color: color ?? AppTheme.textPrimary, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121214),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
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
                color: Colors.white,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                onPressed: _showCreateFolderDialog,
                child: const Icon(Icons.create_new_folder_outlined, color: Colors.black, size: 24),
              ),
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack)
          : null,
      bottomNavigationBar: _selectionMode && (_selectedFolderIds.isNotEmpty || _selectedFileIds.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF09090B),
                border: Border(top: BorderSide(color: Color(0xFF27272A))),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBatchActionButton(
                      icon: Icons.folder_shared_outlined,
                      label: 'MOVE',
                      onTap: batchMoveSelected,
                    ),
                    _buildBatchActionButton(
                      icon: Icons.unarchive_outlined,
                      label: 'EXTRACT',
                      onTap: batchExtractSelected,
                    ),
                    _buildBatchActionButton(
                      icon: Icons.delete_outline,
                      label: 'DELETE',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: !_selectionMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '> DIRECTORY_INDEX',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_folders.isNotEmpty || _files.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.check_box_outlined, color: Colors.white, size: 22),
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
                              icon: const Icon(Icons.close, color: AppTheme.textPrimary),
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
                              '${_selectedFolderIds.length + _selectedFileIds.length} SELECTED',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _selectAll,
                          icon: const Icon(Icons.select_all, color: Colors.white, size: 18),
                          label: Text(
                            _selectedFolderIds.length + _selectedFileIds.length == filteredFolders.length + filteredFiles.length
                                ? 'DESELECT ALL'
                                : 'SELECT ALL',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 11),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'FILTER FILES AND DIRECTORIES...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace'),
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
                        child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                      )
                    else
                      const Icon(Icons.filter_alt_outlined, color: AppTheme.textSecondary, size: 18),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 14),

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
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFF09090B),
                        border: Border.all(
                          color: isSelected ? Colors.white : const Color(0xFF27272A),
                        ),
                      ),
                      child: Text(
                        tab.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ).animate(delay: (30 * idx).ms).fadeIn().slideX(begin: 0.1, end: 0);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  border: Border.all(color: const Color(0xFF27272A)),
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
                              Icons.folder_outlined,
                              size: 14,
                              color: _currentFolderId == null ? Colors.white : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '/ROOT',
                              style: TextStyle(
                                color: _currentFolderId == null ? Colors.white : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
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
                              child: Text('/', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace')),
                            ),
                            GestureDetector(
                              onTap: () => _navigateToFolder(crumb.id),
                              child: Text(
                                crumb.name.toUpperCase(),
                                style: TextStyle(
                                  color: isLast ? Colors.white : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                                  fontFamily: 'monospace',
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

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : (filteredFolders.isEmpty && filteredFiles.isEmpty)
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF09090B),
                              border: Border.all(color: const Color(0xFF27272A)),
                            ),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121214),
                                    border: Border.all(color: const Color(0xFF27272A)),
                                  ),
                                  child: const Icon(
                                    Icons.folder_open,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedTab != 'All'
                                      ? 'NO MATCHING ITEMS'
                                      : 'EMPTY DIRECTORY',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedTab != 'All'
                                      ? 'Adjust filter criteria or search query.'
                                      : 'Create a new directory or transfer items from PC.',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ).animate().fadeIn().scale(),
                        )
                      : RefreshIndicator(
                          color: Colors.white,
                          backgroundColor: const Color(0xFF09090B),
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
                                  child: Divider(color: Color(0xFF27272A), height: 1),
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
