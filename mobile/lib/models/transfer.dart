import '../core/formatters.dart';

enum TransferDirection { received, sent }

enum TransferStatus { completed, failed, cancelled }

class Transfer {
  final String id;
  final String fileName;
  final int size;
  final TransferDirection direction;
  final TransferStatus status;
  final String? folderId;
  final int? completedAt;

  const Transfer({
    required this.id,
    required this.fileName,
    required this.size,
    required this.direction,
    required this.status,
    this.folderId,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'size': size,
      'direction': direction.name,
      'status': status.name,
      'folder_id': folderId,
      'completed_at': completedAt,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'] as String? ?? '',
      fileName: map['file_name'] as String? ?? 'Unknown',
      size: map['size'] as int? ?? 0,
      direction: TransferDirection.values.firstWhere(
        (d) => d.name == map['direction'],
        orElse: () => TransferDirection.received,
      ),
      status: TransferStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TransferStatus.failed,
      ),
      folderId: map['folder_id'] as String?,
      completedAt: map['completed_at'] as int?,
    );
  }

  Transfer copyWith({
    String? id,
    String? fileName,
    int? size,
    TransferDirection? direction,
    TransferStatus? status,
    String? folderId,
    int? completedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      folderId: folderId ?? this.folderId,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get formattedSize => Formatters.formatBytes(size);

  @override
  String toString() => 'Transfer(id: $id, fileName: $fileName, status: ${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Transfer && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
