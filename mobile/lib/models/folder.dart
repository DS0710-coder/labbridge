class Folder {
  final String id;
  final String name;
  final String? parentId;
  final String color;
  final bool pinned;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.color = '#6C63FF',
    this.pinned = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'color': color,
      'pinned': pinned ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      color: (map['color'] as String?) ?? '#6C63FF',
      pinned: (map['pinned'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    String? color,
    bool? pinned,
    DateTime? createdAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
