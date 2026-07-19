enum TransferTaskStatus { receiving, decrypting, completed, failed, cancelled }

class TransferTask {
  final String transferId;
  final String filename;
  final int totalSize;
  final int totalChunks;
  final String mimeType;
  int receivedChunks;
  double speedMbps;
  TransferTaskStatus status;
  String? targetFolderId;
  String? savedPath;
  String? errorMessage;

  TransferTask({
    required this.transferId,
    required this.filename,
    required this.totalSize,
    required this.totalChunks,
    required this.mimeType,
    this.receivedChunks = 0,
    this.speedMbps = 0.0,
    this.status = TransferTaskStatus.receiving,
    this.targetFolderId,
    this.savedPath,
    this.errorMessage,
  });

  double get percentage => totalChunks > 0 ? (receivedChunks / totalChunks) * 100 : 0.0;
}
