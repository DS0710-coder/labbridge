class FileItem {
  final String id;
  final String name;
  final String localPath;
  final int size;
  final String? mimeType;
  final String? folderId;
  final int receivedAt;
  final String tags;

  const FileItem({
    required this.id,
    required this.name,
    required this.localPath,
    required this.size,
    this.mimeType,
    this.folderId,
    required this.receivedAt,
    this.tags = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'local_path': localPath,
      'size': size,
      'mime_type': mimeType,
      'folder_id': folderId,
      'received_at': receivedAt,
      'tags': tags,
    };
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as String,
      name: map['name'] as String,
      localPath: map['local_path'] as String,
      size: map['size'] as int,
      mimeType: map['mime_type'] as String?,
      folderId: map['folder_id'] as String?,
      receivedAt: map['received_at'] as int,
      tags: (map['tags'] as String?) ?? '',
    );
  }

  FileItem copyWith({
    String? id,
    String? name,
    String? localPath,
    int? size,
    String? mimeType,
    String? folderId,
    bool clearFolderId = false,
    int? receivedAt,
    String? tags,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      receivedAt: receivedAt ?? this.receivedAt,
      tags: tags ?? this.tags,
    );
  }

  List<String> get tagList =>
      tags.isEmpty ? [] : tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() => 'FileItem(id: $id, name: $name, size: $size)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FileItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
