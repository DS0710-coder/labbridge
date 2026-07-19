import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../models/file_item.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  static Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'labbridge.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            color TEXT,
            pinned INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE files (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folder_id TEXT,
            local_path TEXT NOT NULL,
            size INTEGER NOT NULL,
            mime_type TEXT,
            transferred_at TEXT NOT NULL,
            device_name TEXT,
            tags TEXT,
            FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
          )
        ''');

        // Seed default academic folders
        final now = DateTime.now().toUtc().toIso8601String();
        final sem1Id = _uuid.v4();
        final sem2Id = _uuid.v4();
        final labId = _uuid.v4();

        await db.insert('folders', {
          'id': sem1Id,
          'name': 'Semester 1',
          'parent_id': null,
          'color': '#6C63FF',
          'pinned': 1,
          'created_at': now,
        });

        await db.insert('folders', {
          'id': sem2Id,
          'name': 'Semester 2',
          'parent_id': null,
          'color': '#3B82F6',
          'pinned': 0,
          'created_at': now,
        });

        await db.insert('folders', {
          'id': labId,
          'name': 'Lab Practicals',
          'parent_id': sem1Id,
          'color': '#22C55E',
          'pinned': 1,
          'created_at': now,
        });
      },
    );
  }

  // Folder operations
  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'pinned DESC, name ASC');
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<List<Folder>> getFoldersByParent(String? parentId) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? [] : [parentId],
      orderBy: 'pinned DESC, name ASC',
    );
    return maps.map((m) => Folder.fromMap(m)).toList();
  }

  Future<int> insertFolder(Folder folder) async {
    final db = await database;
    return await db.insert('folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateFolder(Folder folder) async {
    final db = await database;
    return await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<int> deleteFolder(String id) async {
    final db = await database;
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // File operations
  Future<List<FileItem>> getAllFiles() async {
    final db = await database;
    final maps = await db.query('files', orderBy: 'transferred_at DESC');
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<List<FileItem>> getFilesByFolder(String? folderId) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: folderId == null ? 'folder_id IS NULL' : 'folder_id = ?',
      whereArgs: folderId == null ? [] : [folderId],
      orderBy: 'transferred_at DESC',
    );
    return maps.map((m) => FileItem.fromMap(m)).toList();
  }

  Future<int> insertFile(FileItem file) async {
    final db = await database;
    return await db.insert('files', file.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> deleteFile(String id) async {
    final db = await database;
    final item = await db.query('files', where: 'id = ?', whereArgs: [id]);
    if (item.isNotEmpty) {
      final path = item.first['local_path'] as String;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    return await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }
}
