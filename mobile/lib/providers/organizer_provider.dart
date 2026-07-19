import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../models/file_item.dart';
import '../services/db_service.dart';

class OrganizerProvider extends ChangeNotifier {
  final DbService _db = DbService();
  final _uuid = const Uuid();

  List<Folder> _folders = [];
  List<FileItem> _files = [];
  final List<Folder> _breadcrumbs = [];
  bool _isLoading = false;

  List<Folder> get folders => _folders;
  List<FileItem> get files => _files;
  List<Folder> get breadcrumbs => _breadcrumbs;
  Folder? get currentFolder => _breadcrumbs.isEmpty ? null : _breadcrumbs.last;
  bool get isLoading => _isLoading;

  Future<void> loadCurrentView() async {
    _isLoading = true;
    notifyListeners();

    final parentId = currentFolder?.id;
    _folders = await _db.getFoldersByParent(parentId);
    _files = await _db.getFilesByFolder(parentId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateToFolder(Folder folder) async {
    _breadcrumbs.add(folder);
    await loadCurrentView();
  }

  Future<void> navigateUp() async {
    if (_breadcrumbs.isNotEmpty) {
      _breadcrumbs.removeLast();
      await loadCurrentView();
    }
  }

  Future<void> navigateToRoot() async {
    _breadcrumbs.clear();
    await loadCurrentView();
  }

  Future<void> createFolder(String name, {String color = '#6C63FF'}) async {
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: currentFolder?.id,
      color: color,
      pinned: false,
      createdAt: DateTime.now().toUtc(),
    );

    await _db.insertFolder(folder);
    await loadCurrentView();
  }

  Future<void> togglePin(Folder folder) async {
    final updated = folder.copyWith(pinned: !folder.pinned);
    await _db.updateFolder(updated);
    await loadCurrentView();
  }

  Future<void> deleteFolder(Folder folder) async {
    await _db.deleteFolder(folder.id);
    await loadCurrentView();
  }

  Future<void> deleteFileItem(FileItem file) async {
    await _db.deleteFile(file.id);
    await loadCurrentView();
  }

  Future<void> addTransferredFile(FileItem file) async {
    await _db.insertFile(file);
    await loadCurrentView();
  }
}
