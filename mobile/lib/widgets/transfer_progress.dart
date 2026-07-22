import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../main.dart';

class TransferProgressWidget extends StatefulWidget {
  final TransferProgress transferProgress;
  final double? speed; // bytes per second

  const TransferProgressWidget({
    super.key,
    required this.transferProgress,
    this.speed,
  });

  @override
  State<TransferProgressWidget> createState() => _TransferProgressWidgetState();
}

class _TransferProgressWidgetState extends State<TransferProgressWidget> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.transferProgress;
    final isReceiving = progress.direction == TransferDirection.received;
    final progressColor = isReceiving ? const Color(0xFF22C55E) : const Color(0xFFFFFFFF);
    final directionLabel = isReceiving ? 'RECEIVING' : 'SENDING';
    final directionIcon = isReceiving ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border.all(color: const Color(0xFF27272A), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Icon(directionIcon, color: progressColor, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                directionLabel,
                style: TextStyle(
                  color: progressColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                progress.percentage,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            progress.fileName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 14),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.progress.clamp(0.0, 1.0),
              child: Container(
                color: progressColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Formatters.formatBytes(progress.transferredBytes)} / ${Formatters.formatBytes(progress.totalBytes)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              if (widget.speed != null && widget.speed! > 0)
                Text(
                  Formatters.formatSpeed(widget.speed),
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
