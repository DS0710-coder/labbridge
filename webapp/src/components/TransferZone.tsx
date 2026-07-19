import React, { useState, useRef } from 'react';
import { UploadCloud, CheckCircle2 } from 'lucide-react';

interface TransferZoneProps {
  onFileSelect: (file: File) => void;
  disabled?: boolean;
}

export const TransferZone: React.FC<TransferZoneProps> = ({ onFileSelect, disabled }) => {
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!disabled) setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
    if (disabled) return;

    const files = e.dataTransfer.files;
    if (files && files.length > 0) {
      onFileSelect(files[0]);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (files && files.length > 0) {
      onFileSelect(files[0]);
    }
  };

  return (
    <div
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      onClick={() => !disabled && fileInputRef.current?.click()}
      className={`relative w-full max-w-2xl mx-auto h-72 rounded-2xl border-2 border-dashed flex flex-col items-center justify-center p-8 transition-all duration-300 cursor-pointer ${
        disabled
          ? 'opacity-50 cursor-not-allowed border-[#1E1E2E] bg-[#111118]'
          : isDragging
          ? 'border-[#6C63FF] bg-[#6C63FF]/10 scale-[1.01] shadow-2xl'
          : 'border-[#1E1E2E] bg-[#111118] hover:border-[#6C63FF]/50 hover:bg-[#111118]/80'
      }`}
    >
      <input
        ref={fileInputRef}
        type="file"
        onChange={handleFileChange}
        className="hidden"
        disabled={disabled}
      />

      <div
        className={`w-16 h-16 rounded-full flex items-center justify-center mb-4 transition-transform duration-300 ${
          isDragging ? 'scale-110 bg-[#6C63FF] text-white' : 'bg-[#1E1E2E] text-[#6C63FF]'
        }`}
      >
        <UploadCloud className="w-8 h-8" />
      </div>

      <h3 className="text-lg font-semibold text-[#E8E8F0] mb-2 text-center">
        {isDragging ? 'Drop file here to send instantly!' : 'Drag & drop any file here, or click to browse'}
      </h3>

      <p className="text-sm text-[#6B6B80] text-center max-w-md mb-4">
        Files are encrypted with AES-256-GCM on this device and relayed straight to your phone in under 10 seconds.
      </p>

      <div className="flex items-center gap-4 text-xs font-mono text-[#6B6B80]">
        <span className="flex items-center gap-1">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" /> Max 500MB
        </span>
        <span className="flex items-center gap-1">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" /> Zero Server Storage
        </span>
        <span className="flex items-center gap-1">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" /> Auto Folder Sync
        </span>
      </div>
    </div>
  );
};
