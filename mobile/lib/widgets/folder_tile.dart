import 'package:flutter/material.dart';
import '../models/folder.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
  });

  Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final folderColor = _parseColor(folder.color);

    return Card(
      color: const Color(0xFF111118),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF1E1E2E), width: 1),
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
