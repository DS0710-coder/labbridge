import React from 'react';
import { FileText, CheckCircle, XCircle, Loader2, Zap } from 'lucide-react';
import type { TransferProgress, TransferStatus } from '../hooks/useTransfer';

interface ProgressBarProps {
  file: File | null;
  status: TransferStatus;
  progress: TransferProgress;
  onCancel?: () => void;
  onReset?: () => void;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  file,
  status,
  progress,
  onCancel,
  onReset,
}) => {
  if (!file) return null;

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  };

  return (
    <div className="w-full max-w-2xl mx-auto p-6 bg-[#111118] border border-[#1E1E2E] rounded-2xl shadow-xl mt-6 space-y-5 transition-all">
      {/* File info header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3.5">
          <div className="w-12 h-12 rounded-xl bg-[#6C63FF]/15 border border-[#6C63FF]/30 flex items-center justify-center text-[#6C63FF] shrink-0">
            <FileText className="w-6 h-6" />
          </div>
          <div className="overflow-hidden">
            <h4 className="text-sm font-semibold text-[#E8E8F0] truncate max-w-[280px] font-mono">
              {file.name}
            </h4>
            <span className="text-xs text-[#6B6B80] font-mono">{formatSize(file.size)}</span>
          </div>
        </div>

        {/* Status Badge */}
        <div className="flex items-center gap-3">
          {status === 'uploading' && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-[#6C63FF]/10 border border-[#6C63FF]/30 text-xs font-medium text-[#6C63FF]">
              <Loader2 className="w-3.5 h-3.5 animate-spin" />
              <span>Relaying ({progress.percentage}%)</span>
            </div>
          )}
          {status === 'completed' && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-xs font-medium text-emerald-400">
              <CheckCircle className="w-3.5 h-3.5" />
              <span>Sent to Phone!</span>
            </div>
          )}
          {status === 'cancelled' && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-gray-500/10 border border-gray-500/30 text-xs font-medium text-gray-400">
              <XCircle className="w-3.5 h-3.5" />
              <span>Cancelled</span>
            </div>
          )}
          {status === 'error' && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/30 text-xs font-medium text-red-400">
              <XCircle className="w-3.5 h-3.5" />
              <span>Transfer Error</span>
            </div>
          )}
        </div>
      </div>

      {/* Main Overall Progress Bar */}
      <div className="space-y-1.5">
        <div className="flex justify-between text-xs font-mono">
          <span className="text-[#6B6B80]">Overall Encryption & Relay</span>
          <span className="text-[#E8E8F0] font-bold">{progress.percentage}%</span>
        </div>
        <div className="w-full h-3 bg-[#1E1E2E] rounded-full overflow-hidden p-0.5">
          <div
            className={`h-full rounded-full transition-all duration-300 ${
              status === 'completed'
                ? 'bg-emerald-500'
                : status === 'error'
                ? 'bg-red-500'
                : 'bg-gradient-to-r from-[#6C63FF] to-indigo-400 glow-accent'
            }`}
            style={{ width: `${progress.percentage}%` }}
          />
        </div>
      </div>

      {/* Chunk info & speed */}
      <div className="flex items-center justify-between text-xs font-mono text-[#6B6B80] pt-1 border-t border-[#1E1E2E]/60">
        <div>
          <span>Chunk: </span>
          <span className="text-[#E8E8F0]">
            {progress.currentChunk} / {progress.totalChunks}
          </span>
        </div>

        {status === 'uploading' && progress.speedMbps > 0 && (
          <div className="flex items-center gap-1 text-[#6C63FF]">
            <Zap className="w-3.5 h-3.5 fill-current" />
            <span>{progress.speedMbps} Mbps</span>
          </div>
        )}

        {status === 'uploading' && onCancel && (
          <button
            onClick={onCancel}
            className="text-red-400 hover:text-red-300 underline transition"
          >
            Cancel Relay
          </button>
        )}

        {(status === 'completed' || status === 'cancelled' || status === 'error') && onReset && (
          <button
            onClick={onReset}
            className="px-3 py-1 rounded bg-[#6C63FF] text-white hover:bg-[#5a52d4] font-sans font-medium transition"
          >
            Send Another File
          </button>
        )}
      </div>
    </div>
  );
};
