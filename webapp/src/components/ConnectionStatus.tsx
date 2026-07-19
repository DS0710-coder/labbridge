import React from 'react';
import { Smartphone, LogOut, ShieldCheck } from 'lucide-react';

interface ConnectionStatusProps {
  deviceName: string | null;
  onDisconnect: () => void;
}

export const ConnectionStatus: React.FC<ConnectionStatusProps> = ({
  deviceName,
  onDisconnect,
}) => {
  if (!deviceName) return null;

  return (
    <div className="flex items-center justify-between px-6 py-3 bg-[#111118] border border-[#1E1E2E] rounded-xl shadow-lg w-full max-w-2xl mx-auto mb-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-full bg-[#6C63FF]/20 border border-[#6C63FF]/40 flex items-center justify-center text-[#6C63FF]">
          <Smartphone className="w-5 h-5" />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-[#E8E8F0]">{deviceName}</span>
            <span className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-[10px] font-mono text-emerald-400">
              <ShieldCheck className="w-3 h-3" /> Encrypted Relay
            </span>
          </div>
          <p className="text-xs text-[#6B6B80]">Connected over real-time WebSocket</p>
        </div>
      </div>

      <button
        onClick={onDisconnect}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[#1E1E2E] hover:bg-red-500/10 text-[#6B6B80] hover:text-red-400 border border-transparent hover:border-red-500/30 text-xs font-medium transition-all duration-200"
      >
        <LogOut className="w-3.5 h-3.5" />
        <span>Disconnect</span>
      </button>
    </div>
  );
};
