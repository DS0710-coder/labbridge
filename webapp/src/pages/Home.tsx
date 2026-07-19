import React from 'react';
import { Zap, Shield, FolderGit2, ArrowRight } from 'lucide-react';
import { QRDisplay } from '../components/QRDisplay';
import type { QRPayload } from '../services/api';
import type { PairingStatus } from '../hooks/usePairing';

interface HomeProps {
  qrPayload?: QRPayload;
  status: PairingStatus;
  secondsLeft: number;
  deviceName: string | null;
  onRefresh: () => void;
  onGoToTransfer: () => void;
}

export const Home: React.FC<HomeProps> = ({
  qrPayload,
  status,
  secondsLeft,
  deviceName,
  onRefresh,
  onGoToTransfer,
}) => {
  return (
    <div className="min-h-screen flex flex-col justify-between py-12 px-4 sm:px-6 lg:px-8">
      {/* Header */}
      <header className="max-w-6xl mx-auto w-full flex items-center justify-between mb-12">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-[#6C63FF] to-indigo-400 flex items-center justify-center shadow-lg shadow-[#6C63FF]/30">
            <Zap className="w-6 h-6 text-white fill-current" />
          </div>
          <span className="text-2xl font-black tracking-tight text-white">
            Lab<span className="text-[#6C63FF]">Bridge</span>
          </span>
        </div>

        <div className="flex items-center gap-4 text-sm font-mono text-[#6B6B80]">
          <span>Zero-Disk Relay</span>
          <span className="w-1.5 h-1.5 rounded-full bg-[#6C63FF]" />
          <span>AES-256-GCM</span>
        </div>
      </header>

      {/* Main Content Grid */}
      <main className="max-w-6xl mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-12 items-center my-auto">
        {/* Left Column: Value Proposition */}
        <div className="lg:col-span-6 space-y-6">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#6C63FF]/10 border border-[#6C63FF]/30 text-xs font-semibold text-[#6C63FF] uppercase tracking-wider">
            Built for College Lab PCs
          </div>

          <h1 className="text-4xl sm:text-5xl font-extrabold text-white leading-tight">
            Transfer Lab Files to Phone in <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#6C63FF] to-indigo-300">Under 10s</span>.
          </h1>

          <p className="text-lg text-[#6B6B80] leading-relaxed">
            No Google Drive login. No WhatsApp Web clutter. No USB drives. Scan the QR with your phone and drag files straight into your academic folder tree.
          </p>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4">
            <div className="p-4 bg-[#111118] border border-[#1E1E2E] rounded-xl flex gap-3 items-start">
              <Shield className="w-5 h-5 text-[#6C63FF] shrink-0 mt-0.5" />
              <div>
                <h4 className="text-sm font-bold text-[#E8E8F0]">End-to-End Encrypted</h4>
                <p className="text-xs text-[#6B6B80] mt-1">
                  Files are encrypted before leaving this browser using HKDF & AES-256-GCM.
                </p>
              </div>
            </div>

            <div className="p-4 bg-[#111118] border border-[#1E1E2E] rounded-xl flex gap-3 items-start">
              <FolderGit2 className="w-5 h-5 text-emerald-500 shrink-0 mt-0.5" />
              <div>
                <h4 className="text-sm font-bold text-[#E8E8F0]">Auto-Organized</h4>
                <p className="text-xs text-[#6B6B80] mt-1">
                  Transfers land straight into your Semester / Subject folders on mobile.
                </p>
              </div>
            </div>
          </div>

          {status === 'paired' && (
            <div className="pt-4">
              <button
                onClick={onGoToTransfer}
                className="w-full sm:w-auto px-8 py-4 bg-gradient-to-r from-[#6C63FF] to-indigo-500 text-white rounded-xl font-bold shadow-xl hover:shadow-[#6C63FF]/40 flex items-center justify-center gap-2 transition transform hover:-translate-y-0.5"
              >
                <span>Launch Transfer Zone</span>
                <ArrowRight className="w-5 h-5" />
              </button>
            </div>
          )}
        </div>

        {/* Right Column: QR Code Display */}
        <div className="lg:col-span-6 flex justify-center">
          <QRDisplay
            qrPayload={qrPayload}
            status={status}
            secondsLeft={secondsLeft}
            deviceName={deviceName}
            onRefresh={onRefresh}
          />
        </div>
      </main>

      {/* Footer */}
      <footer className="max-w-6xl mx-auto w-full pt-12 border-t border-[#1E1E2E] mt-12 flex flex-col sm:flex-row items-center justify-between text-xs text-[#6B6B80] font-mono">
        <div>LabBridge Phase 1 — College Lab Relay Service</div>
        <div className="mt-2 sm:mt-0 flex items-center gap-4">
          <span>Server: Ephemeral RAM Relay</span>
          <span>Storage: 0 Bytes</span>
        </div>
      </footer>
    </div>
  );
};
