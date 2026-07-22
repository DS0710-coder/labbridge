import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

import '../models/folder.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';
import '../main.dart';
import 'files_screen.dart';

/// Top-level compute isolate function for extracting ZIP archives safely via streams without OOM.
Future<List<Map<String, dynamic>>> extractZipStreamWorker(Map<String, String> args) async {
  final zipPath = args['zipPath']!;
  final parentDirPath = args['parentDirPath']!;
  final folderId = args['folderId']!;
  final results = <Map<String, dynamic>>[];

  final inputStream = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(inputStream);
    for (final file in archive) {
      if (file.isFile) {
        final safeName = p.basename(file.name.replaceAll(RegExp(r'[\\/]+'), '_'));
        if (safeName.isEmpty || safeName == '_' || safeName == '.') continue;

        final destPath = p.join(parentDirPath, 'lb_ext_${const Uuid().v4()}_$safeName');
        if (!p.isWithin(parentDirPath, destPath)) continue;

        final outputStream = OutputFileStream(destPath);
        try {
          file.writeContent(outputStream);
        } finally {
          outputStream.close();
        }

        final fileStat = await File(destPath).stat();
        results.add({
          'name': safeName,
          'localPath': destPath,
          'size': fileStat.size,
          'folderId': folderId,
        });
      }
    }
  } finally {
    inputStream.close();
  }
  return results;
}

/// Mixin providing batch operations (delete, move, zip extraction, and unpacking) for [FilesScreen].
mixin FilesBatchMixin<T extends FilesScreen> on State<T> {
  Set<String> get selectedFolderIds;
  Set<String> get selectedFileIds;
  String? get currentFolderId;
  List<Folder> get breadcrumbs;
  List<FileItem> get files;
  DbService get dbService;
  Uuid get uuid;
  void loadFolder(String? folderId);

  Future<void> batchDeleteSelected() async {
    final count = selectedFolderIds.length + selectedFileIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text('DELETE SELECTED ITEMS?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: Text(
          'Are you sure you want to delete $count selected item(s)? Sub-directories will be unlinked.',
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

    if (confirm == true) {
      if (!mounted) return;
      for (final id in selectedFolderIds) {
        await dbService.deleteFolder(id);
      }
      for (final id in selectedFileIds) {
        await dbService.deleteFile(id);
      }
      loadFolder(currentFolderId);
    }
  }

  bool _isDescendantOfSelected(Folder folder, List<Folder> allFolders) {
    String? currentId = folder.parentId;
    while (currentId != null) {
      if (selectedFolderIds.contains(currentId)) return true;
      final parent = allFolders.cast<Folder?>().firstWhere(
        (f) => f?.id == currentId,
        orElse: () => null,
      );
      currentId = parent?.parentId;
    }
    return false;
  }

  Future<void> batchMoveSelected() async {
    final count = selectedFolderIds.length + selectedFileIds.length;
    if (count == 0) return;

    final allFolders = await dbService.getAllFolders();
    if (!mounted) return;

    final destId = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text('MOVE SELECTED TO DIRECTORY', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
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
              ...allFolders
                  .where((f) => !selectedFolderIds.contains(f.id) && !_isDescendantOfSelected(f, allFolders))
                  .map((f) => ListTile(
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

    if (destId != null) {
      final targetFolderId = destId == '__root__' ? null : destId;
      for (final id in selectedFolderIds) {
        final f = await dbService.getFolder(id);
        if (f != null) {
          await dbService.updateFolder(
            targetFolderId == null
                ? f.copyWith(clearParentId: true)
                : f.copyWith(parentId: targetFolderId),
          );
        }
      }
      for (final id in selectedFileIds) {
        final matches = files.where((item) => item.id == id);
        if (matches.isEmpty) continue;
        final f = matches.first;
        await dbService.updateFile(
          targetFolderId == null
              ? f.copyWith(clearFolderId: true)
              : f.copyWith(folderId: targetFolderId),
        );
      }
      loadFolder(currentFolderId);
    }
  }

  Future<void> batchExtractSelected() async {
    final count = selectedFolderIds.length + selectedFileIds.length;
    if (count == 0) return;

    final zipFiles = files.where((f) => selectedFileIds.contains(f.id) && f.name.toLowerCase().endsWith('.zip')).toList();

    if (zipFiles.isNotEmpty) {
      final confirmZip = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF09090B),
          shape: Border.all(color: const Color(0xFF27272A), width: 1),
          title: const Text('EXTRACT ZIP ARCHIVES?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          content: Text(
            'Extract ${zipFiles.length} Zip archive(s) into the current directory?',
            style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EXTRACT', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmZip == true) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        int extractedCount = 0;
        for (final z in zipFiles) {
          try {
            final parentDir = File(z.localPath).parent;
            final extracted = await compute(extractZipStreamWorker, {
              'zipPath': z.localPath,
              'parentDirPath': parentDir.path,
              'folderId': currentFolderId ?? '',
            });
            for (final item in extracted) {
              final folderIdStr = item['folderId'] as String;
              await dbService.insertFile(FileItem(
                id: uuid.v4(),
                name: item['name'] as String,
                localPath: item['localPath'] as String,
                size: item['size'] as int,
                folderId: folderIdStr.isEmpty ? null : folderIdStr,
                receivedAt: DateTime.now().millisecondsSinceEpoch,
              ));
              extractedCount++;
            }
          } catch (e) {
            debugPrint('Error extracting zip: $e');
          }
        }
        if (extractedCount > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Successfully extracted $extractedCount file(s)!', style: const TextStyle(fontFamily: 'monospace')),
              backgroundColor: const Color(0xFF22C55E),
            ),
          );
        }
        loadFolder(currentFolderId);
        return;
      }
    }

    if (!mounted) return;
    final confirmUnpack = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF09090B),
        shape: Border.all(color: const Color(0xFF27272A), width: 1),
        title: const Text('UNPACK TO PARENT DIRECTORY?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
        content: Text(
          'Move $count selected item(s) up to the parent directory (${breadcrumbs.length > 1 ? breadcrumbs[breadcrumbs.length - 2].name.toUpperCase() : 'ROOT'})?',
          style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('UNPACK', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmUnpack == true) {
      final parentFolderId = breadcrumbs.length > 1 ? breadcrumbs[breadcrumbs.length - 2].id : null;
      for (final id in selectedFolderIds) {
        final f = await dbService.getFolder(id);
        if (f != null) {
          await dbService.updateFolder(
            parentFolderId == null
                ? f.copyWith(clearParentId: true)
                : f.copyWith(parentId: parentFolderId),
          );
        }
      }
      for (final id in selectedFileIds) {
        final matches = files.where((item) => item.id == id);
        if (matches.isEmpty) continue;
        final f = matches.first;
        await dbService.updateFile(
          parentFolderId == null
              ? f.copyWith(clearFolderId: true)
              : f.copyWith(folderId: parentFolderId),
        );
      }
      loadFolder(currentFolderId);
    }
  }
}
