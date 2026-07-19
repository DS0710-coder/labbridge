import React from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Smartphone, RefreshCw, ShieldCheck } from 'lucide-react';
import type { QRPayload } from '../services/api';
import type { PairingStatus } from '../hooks/usePairing';

interface QRDisplayProps {
  qrPayload?: QRPayload;
  status: PairingStatus;
  secondsLeft: number;
  deviceName: string | null;
  onRefresh: () => void;
}

export const QRDisplay: React.FC<QRDisplayProps> = ({
  qrPayload,
  status,
  secondsLeft,
  deviceName,
  onRefresh,
}) => {
  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const pctLeft = (secondsLeft / 120) * 100;

  return (
    <div className="flex flex-col items-center justify-center p-8 bg-[#111118] border border-[#1E1E2E] rounded-2xl shadow-2xl max-w-md w-full mx-auto relative overflow-hidden transition-all duration-300 hover:border-[#6C63FF]/40">
      {/* Top Header Badge */}
      <div className="flex items-center gap-2 mb-6 px-4 py-1.5 rounded-full bg-[#1E1E2E]/80 border border-[#6C63FF]/30 text-sm font-medium text-[#E8E8F0]">
        <Smartphone className="w-4 h-4 text-[#6C63FF]" />
        <span>Scan with LabBridge Mobile</span>
      </div>

      {/* QR Code Container with Glowing Frame */}
      <div className="relative p-6 bg-white rounded-2xl shadow-lg glow-accent mb-6 flex items-center justify-center">
        {status === 'waiting' && qrPayload ? (
          <QRCodeSVG
            value={JSON.stringify(qrPayload)}
            size={230}
            level="M"
            includeMargin={false}
          />
        ) : status === 'connecting' ? (
          <div className="w-[230px] h-[230px] flex flex-col items-center justify-center gap-3 text-gray-800 font-medium">
            <RefreshCw className="w-8 h-8 text-[#6C63FF] animate-spin" />
            <span>Generating Secure QR...</span>
          </div>
        ) : status === 'paired' ? (
          <div className="w-[230px] h-[230px] flex flex-col items-center justify-center gap-3 text-emerald-600 font-medium bg-emerald-50 rounded-xl p-4 text-center">
            <ShieldCheck className="w-16 h-16 text-emerald-500 animate-bounce" />
            <span className="text-lg font-bold">Connected!</span>
            <span className="text-xs text-gray-600 font-mono">{deviceName}</span>
          </div>
        ) : (
          <div className="w-[230px] h-[230px] flex flex-col items-center justify-center gap-3 text-red-500 font-medium text-center p-4">
            <span>Failed to load QR</span>
            <button
              onClick={onRefresh}
              className="px-4 py-2 bg-[#6C63FF] text-white rounded-lg text-xs font-semibold hover:bg-[#5b52e0] transition"
            >
              Retry
            </button>
          </div>
        )}
      </div>

      {/* Expiry Timer Bar */}
      {status === 'waiting' && (
        <div className="w-full space-y-2 mb-4">
          <div className="flex justify-between items-center text-xs text-[#6B6B80] font-mono">
            <span>QR Auto-Refreshes in</span>
            <span className="text-[#E8E8F0] font-bold text-sm">{formatTime(secondsLeft)}</span>
          </div>
          <div className="w-full h-1.5 bg-[#1E1E2E] rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-[#6C63FF] to-indigo-400 transition-all duration-1000 ease-linear rounded-full"
              style={{ width: `${pctLeft}%` }}
            />
          </div>
        </div>
      )}

      {/* Status Description */}
      <div className="text-center space-y-1">
        {status === 'waiting' && (
          <p className="text-sm text-[#6B6B80]">
            Point your phone camera at the QR code to pair instantly across devices without login.
          </p>
        )}
        {status === 'paired' && (
          <p className="text-sm text-emerald-400 font-medium">
            Paired with {deviceName}. Ready to receive files!
          </p>
        )}
      </div>

      {/* Manual refresh action */}
      {status === 'waiting' && (
        <button
          onClick={onRefresh}
          className="mt-4 flex items-center gap-1.5 text-xs text-[#6B6B80] hover:text-[#6C63FF] transition py-1 px-3 rounded-md hover:bg-[#1E1E2E]"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh Now</span>
        </button>
      )}
    </div>
  );
};
