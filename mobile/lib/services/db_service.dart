import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../models/file_item.dart';
import '../models/transfer.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Database? _database;
  Future<Database>? _initFuture;
  static const _uuid = Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _initFuture ??= _initDatabase();
    try {
      _database = await _initFuture!;
      return _database!;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'labbridge_v2.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        color TEXT DEFAULT '#6C63FF',
        sort_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE files (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        local_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        mime_type TEXT,
        folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
        received_at INTEGER NOT NULL,
        tags TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        size INTEGER NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        folder_id TEXT,
        completed_at INTEGER
      )
    ''');

    // Seed default folders
    final now = DateTime.now().millisecondsSinceEpoch;
    final sem1Id = _uuid.v4();
    final sem2Id = _uuid.v4();
    final labPracticalsId = _uuid.v4();

    await db.insert('folders', {
      'id': sem1Id,
      'name': 'Semester 1',
      'parent_id': null,
      'color': '#6C63FF',
      'sort_order': 0,
      'created_at': now,
    });

    await db.insert('folders', {
      'id': sem2Id,
      'name': 'Semester 2',
      'parent_id': null,
      'color': '#22C55E',
      'sort_order': 1,
      'created_at': now,
    });

    await db.insert('folders', {
      'id': labPracticalsId,
      'name': 'Lab Practicals',
      'parent_id': sem1Id,
      'color': '#EF4444',
      'sort_order': 0,
      'created_at': now,
    });
  }

  Future<void> init() async {
    await database;
  }

  // ─── Folders ──────────────────────────────────────────

  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'sort_order ASC');
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<List<Folder>> getChildFolders(String? parentId) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<Folder?> getFolder(String id) async {
    final db = await database;
    final maps = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Folder.fromMap(maps.first);
  }

  Future<void> insertFolder(Folder folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap());
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    // Move children to parent of deleted folder
    final folder = await getFolder(id);
    if (folder != null) {
      await db.update(
        'folders',
        {'parent_id': folder.parentId},
        where: 'parent_id = ?',
        whereArgs: [id],
      );
    }
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFolderTree() async {
    final allFolders = await getAllFolders();
    return _buildTree(allFolders, null);
  }

  List<Map<String, dynamic>> _buildTree(List<Folder> allFolders, String? parentId) {
    final children = allFolders.where((f) => f.parentId == parentId).toList();
    return children.map((folder) {
      final json = folder.toJson();
      json['children'] = _buildTree(allFolders, folder.id);
      return json;
    }).toList();
  }

  // ─── Files ────────────────────────────────────────────

  Future<List<FileItem>> getAllFiles() async {
    final db = await database;
    final maps = await db.query('files', orderBy: 'received_at DESC');
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<List<FileItem>> getFilesInFolder(String? folderId) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: folderId == null ? 'folder_id IS NULL' : 'folder_id = ?',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: 'received_at DESC',
    );
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<List<FileItem>> getRecentFiles(int limit) async {
    final db = await database;
    final maps = await db.query('files', orderBy: 'received_at DESC', limit: limit);
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<void> insertFile(FileItem file) async {
    final db = await database;
    await db.insert('files', file.toMap());
  }

  Future<void> updateFile(FileItem file) async {
    final db = await database;
    await db.update('files', file.toMap(), where: 'id = ?', whereArgs: [file.id]);
  }

  Future<void> deleteFile(String id) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getStorageUsed() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(size), 0) as total FROM files');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getFilesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM files');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getFoldersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM folders');
    return (result.first['count'] as int?) ?? 0;
  }

  // ─── Transfers ────────────────────────────────────────

  Future<List<Transfer>> getAllTransfers() async {
    final db = await database;
    final maps = await db.query('transfers', orderBy: 'completed_at DESC');
    return maps.map((m) => Transfer.fromMap(m)).toList();
  }

  Future<void> insertTransfer(Transfer transfer) async {
    final db = await database;
    await db.insert('transfers', transfer.toMap());
  }

  Future<void> deleteTransfer(String id) async {
    final db = await database;
    await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Danger Zone ──────────────────────────────────────

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transfers');
    await db.delete('files');
    await db.delete('folders');

    // Re-seed default folders
    await _onCreate(db, 1);
  }
}
