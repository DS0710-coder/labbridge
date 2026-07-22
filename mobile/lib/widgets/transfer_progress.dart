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

class _TransferProgressWidgetState extends State<TransferProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.transferProgress;
    final isReceiving = progress.direction == TransferDirection.received;
    final progressColor = isReceiving ? const Color(0xFF22C55E) : AppTheme.accent;
    final directionLabel = isReceiving ? 'RECEIVING' : 'SENDING';
    final directionIcon = isReceiving ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: progressColor.withValues(alpha: 0.25 * _glowAnimation.value),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              progressColor.withValues(alpha: 0.5),
              progressColor.withValues(alpha: 0.15)
            ],
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(directionIcon, color: progressColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    directionLabel,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    progress.percentage,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                progress.fileName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isReceiving ? AppTheme.gradGreen : AppTheme.gradPrimary,
                          ).createShader(bounds),
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${Formatters.formatBytes(progress.transferredBytes)} / ${Formatters.formatBytes(progress.totalBytes)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (widget.speed != null && widget.speed! > 0)
                    Text(
                      Formatters.formatSpeed(widget.speed),
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
