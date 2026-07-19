import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/organizer_provider.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrganizerProvider>(context, listen: false).loadCurrentView();
    });
  }

  void _showNewFolderModal() {
    final nameController = TextEditingController();
    String selectedColor = '#6C63FF';
    final colors = ['#6C63FF', '#3B82F6', '#22C55E', '#F59E0B', '#EF4444', '#EC4899'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF111118),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Academic Folder', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Data Structures Lab',
                  hintStyle: const TextStyle(color: Color(0xFF6B6B80)),
                  filled: true,
                  fillColor: const Color(0xFF0A0A0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Color Theme', style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: colors.map((hex) {
                  final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                  final isSelected = hex == selectedColor;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final org = Provider.of<OrganizerProvider>(context, listen: false);
                await org.createFolder(nameController.text.trim(), color: selectedColor);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final org = Provider.of<OrganizerProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: Row(
          children: [
            if (org.breadcrumbs.isNotEmpty)
              IconButton(
                onPressed: org.navigateUp,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            Expanded(
              child: Text(
                org.currentFolder?.name ?? 'Academic Organizer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showNewFolderModal,
            icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF6C63FF)),
            tooltip: 'New Folder',
          ),
        ],
      ),
      body: org.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
              onRefresh: org.loadCurrentView,
              color: const Color(0xFF6C63FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Breadcrumbs Bar
                    if (org.breadcrumbs.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: org.navigateToRoot,
                              child: const Text('Root', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            for (var folder in org.breadcrumbs) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('>', style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                              ),
                              Text(folder.name, style: const TextStyle(color: Color(0xFFE8E8F0), fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Subfolders section
                    if (org.folders.isNotEmpty) ...[
                      const Text(
                        'Folders',
                        style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: org.folders.length,
                        itemBuilder: (ctx, idx) {
                          final f = org.folders[idx];
                          final folderColor = _parseHex(f.color);
                          return GestureDetector(
                            onTap: () => org.navigateToFolder(f),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111118),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: f.pinned ? folderColor : const Color(0xFF1E1E2E), width: f.pinned ? 1.5 : 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(Icons.folder_rounded, color: folderColor, size: 28),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => org.togglePin(f),
                                            child: Icon(
                                              f.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                              size: 18,
                                              color: f.pinned ? folderColor : const Color(0xFF6B6B80),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => org.deleteFolder(f),
                                            child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF6B6B80)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    f.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Files section
                    const Text(
                      'Transferred Files',
                      style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    if (org.files.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111118),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.folder_open_rounded, color: Color(0xFF6B6B80), size: 40),
                            SizedBox(height: 12),
                            Text(
                              'No files transferred here yet',
                              style: TextStyle(color: Color(0xFFE8E8F0), fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Scan lab computer QR code to receive files directly into this folder.',
                              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: org.files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final file = org.files[idx];
                          final fileExists = File(file.localPath).existsSync();

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111118),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1E1E2E)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    fileExists ? Icons.insert_drive_file_rounded : Icons.broken_image_rounded,
                                    color: fileExists ? const Color(0xFF6C63FF) : const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            _formatSize(file.size),
                                            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 11, fontFamily: 'monospace'),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Color(0xFF6B6B80))),
                                          Text(
                                            DateFormat('MMM d, h:mm a').format(file.transferredAt.toLocal()),
                                            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      if (file.tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: file.tags.split(',').map((t) {
                                              return Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E1E2E),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(t, style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 10)),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => org.deleteFileItem(file),
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF6B6B80), size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
