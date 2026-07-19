class Folder {
  final String id;
  final String name;
  final String? parentId;
  final String color;
  final int sortOrder;
  final int createdAt;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.color = '#6C63FF',
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      color: (map['color'] as String?) ?? '#6C63FF',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as int,
    );
  }

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParentId = false,
    String? color,
    int? sortOrder,
    int? createdAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'color': color,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() => 'Folder(id: $id, name: $name, parentId: $parentId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Folder && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
