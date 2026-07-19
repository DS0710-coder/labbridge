class FileItem {
  final String id;
  final String name;
  final String? folderId;
  final String localPath;
  final int size;
  final String? mimeType;
  final DateTime transferredAt;
  final String? deviceName;
  final String tags;

  FileItem({
    required this.id,
    required this.name,
    this.folderId,
    required this.localPath,
    required this.size,
    this.mimeType = 'application/octet-stream',
    required this.transferredAt,
    this.deviceName = 'PC Relay',
    this.tags = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'folder_id': folderId,
      'local_path': localPath,
      'size': size,
      'mime_type': mimeType,
      'transferred_at': transferredAt.toIso8601String(),
      'device_name': deviceName,
      'tags': tags,
    };
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as String,
      name: map['name'] as String,
      folderId: map['folder_id'] as String?,
      localPath: map['local_path'] as String,
      size: map['size'] as int,
      mimeType: map['mime_type'] as String?,
      transferredAt: DateTime.parse(map['transferred_at'] as String),
      deviceName: map['device_name'] as String?,
      tags: (map['tags'] as String?) ?? '',
    );
  }
}
