import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';

class TransferProgressWidget extends StatelessWidget {
  final TransferProgress transferProgress;
  final double? speed; // bytes per second

  const TransferProgressWidget({
    super.key,
    required this.transferProgress,
    this.speed,
  });

  String _formatSpeed(double? bytesPerSec) {
    if (bytesPerSec == null || bytesPerSec == 0) return '';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isReceiving = transferProgress.direction == TransferDirection.received;
    final progressColor = isReceiving
        ? const Color(0xFF22C55E)
        : const Color(0xFF3B82F6);
    final directionLabel = isReceiving ? 'Receiving' : 'Sending';
    final directionIcon = isReceiving
        ? Icons.download_rounded
        : Icons.upload_rounded;

    return Card(
      color: const Color(0xFF111118),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: progressColor.withValues(alpha: 0.3), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(directionIcon, color: progressColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  directionLabel,
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  transferProgress.percentage,
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              transferProgress.fileName,
              style: const TextStyle(
                color: Color(0xFFE8E8F0),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: transferProgress.progress,
                backgroundColor: progressColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatBytes(transferProgress.transferredBytes)} / ${_formatBytes(transferProgress.totalBytes)}',
                  style: const TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 12,
                  ),
                ),
                if (speed != null && speed! > 0)
                  Text(
                    _formatSpeed(speed),
                    style: TextStyle(
                      color: progressColor.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
