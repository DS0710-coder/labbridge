class Formatters {
  Formatters._();

  /// Format byte counts / storage size to human readable string (B, KB, MB, GB, TB)
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
  }

  /// Alias for formatBytes to clearly express formatting storage capacity or used space
  static String formatStorage(int bytes) => formatBytes(bytes);

  /// Format transfer speed (bytes per second) to human readable string
  static String formatSpeed(double? bytesPerSec) {
    if (bytesPerSec == null || bytesPerSec <= 0) return '';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    if (bytesPerSec < 1024 * 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSec / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }
}
