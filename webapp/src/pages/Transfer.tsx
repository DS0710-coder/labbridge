import React from 'react';
import { ArrowLeft, Zap, ShieldCheck } from 'lucide-react';
import { ConnectionStatus } from '../components/ConnectionStatus';
import { TransferZone } from '../components/TransferZone';
import { ProgressBar } from '../components/ProgressBar';
import type { TransferProgress, TransferStatus } from '../hooks/useTransfer';

interface TransferPageProps {
  deviceName: string | null;
  activeFile: File | null;
  status: TransferStatus;
  progress: TransferProgress;
  error: string | null;
  onDisconnect: () => void;
  onFileSelect: (file: File) => void;
  onCancelTransfer: () => void;
  onResetTransfer: () => void;
  onBackToQR: () => void;
}

export const TransferPage: React.FC<TransferPageProps> = ({
  deviceName,
  activeFile,
  status,
  progress,
  error,
  onDisconnect,
  onFileSelect,
  onCancelTransfer,
  onResetTransfer,
  onBackToQR,
}) => {
  return (
    <div className="min-h-screen flex flex-col justify-between py-10 px-4 sm:px-6 lg:px-8">
      {/* Top Bar */}
      <header className="max-w-4xl mx-auto w-full flex items-center justify-between mb-8">
        <button
          onClick={onBackToQR}
          className="flex items-center gap-2 text-sm text-[#6B6B80] hover:text-white transition px-3 py-1.5 rounded-lg hover:bg-[#1E1E2E]"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to QR Session</span>
        </button>

        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-[#6C63FF] flex items-center justify-center">
            <Zap className="w-4 h-4 text-white fill-current" />
          </div>
          <span className="font-bold text-white tracking-tight">LabBridge Transfer</span>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-4xl mx-auto w-full flex-1 flex flex-col items-center justify-center">
        <ConnectionStatus deviceName={deviceName || 'Connected Mobile Device'} onDisconnect={onDisconnect} />

        {error && (
          <div className="w-full max-w-2xl mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm font-medium flex items-center justify-between">
            <span>{error}</span>
            <button onClick={onResetTransfer} className="underline text-xs hover:text-red-300">
              Dismiss
            </button>
          </div>
        )}

        <TransferZone
          onFileSelect={onFileSelect}
          disabled={status === 'uploading'}
        />

        {activeFile && (
          <ProgressBar
            file={activeFile}
            status={status}
            progress={progress}
            onCancel={onCancelTransfer}
            onReset={onResetTransfer}
          />
        )}
      </main>

      {/* Footer info */}
      <footer className="max-w-4xl mx-auto w-full pt-8 text-center text-xs text-[#6B6B80] font-mono">
        <div className="flex justify-center items-center gap-6">
          <span className="flex items-center gap-1.5">
            <ShieldCheck className="w-4 h-4 text-emerald-500" /> Client AES-256-GCM Encryption
          </span>
          <span>•</span>
          <span>Relay Latency: &lt; 10s</span>
        </div>
      </footer>
    </div>
  );
};
