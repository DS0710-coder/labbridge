import 'package:flutter/material.dart';
import '../models/folder.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool selectionMode;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
  });

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final folderColor = _parseColor(folder.color);

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: folderColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectionMode)
                Container(
                  width: 24,
                  height: 24,
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
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B6B80),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
