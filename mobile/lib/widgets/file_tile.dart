import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_item.dart';

class FileTile extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool selectionMode;

  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
  });

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file_rounded;
      case 'zip':
      case 'rar':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'java':
      case 'py':
      case 'js':
      case 'dart':
      case 'c':
      case 'cpp':
      case 'html':
      case 'css':
        return Icons.code_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF3B82F6);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF22C55E);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFF97316);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return const Color(0xFFA855F7);
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return const Color(0xFFEC4899);
      case 'zip':
      case 'rar':
      case 'tar':
      case 'gz':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getFileIcon(file.name);
    final color = _getFileColor(file.name);
    final dateStr = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(file.receivedAt),
    );
    final tags = file.tagList;

    return Card(
      color: isSelected ? const Color(0xFF6C63FF).withValues(alpha: 0.08) : const Color(0xFF111118),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1E1E2E),
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Color(0xFFE8E8F0),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.formattedSize} · $dateStr',
                      style: const TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 12,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (selectionMode)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF6B6B80),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
