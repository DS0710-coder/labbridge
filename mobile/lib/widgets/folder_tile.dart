import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/folder.dart';
import '../main.dart';

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

  @override
  Widget build(BuildContext context) {
    final folderColor = AppColors.fromHex(folder.color);

    final borderColors = isSelected
        ? AppTheme.gradPrimary
        : AppTheme.borderGrad;

    final bgColor = isSelected
        ? AppTheme.accent.withValues(alpha: 0.12)
        : AppTheme.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderColors,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.all(1),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        folderColor.withValues(alpha: 0.28),
                        folderColor.withValues(alpha: 0.08)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectionMode)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.textMuted,
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
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
