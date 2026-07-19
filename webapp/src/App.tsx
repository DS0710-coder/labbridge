import React, { useState, useEffect } from 'react';
import { usePairing } from './hooks/usePairing';
import { useTransfer } from './hooks/useTransfer';
import { Home } from './pages/Home';
import { TransferPage } from './pages/Transfer';

export const App: React.FC = () => {
  const {
    session,
    status: pairingStatus,
    deviceName,
    secondsLeft,
    refreshSession,
    disconnect: disconnectPairing,
  } = usePairing();

  const {
    activeFile,
    status: transferStatus,
    progress,
    error: transferError,
    startTransfer,
    cancelTransfer,
    reset: resetTransfer,
  } = useTransfer(
    session?.session_id || null,
    session?.qr_payload?.pairing_token || null
  );

  const [view, setView] = useState<'home' | 'transfer'>('home');

  // Auto-navigate to transfer screen when paired
  useEffect(() => {
    if (pairingStatus === 'paired') {
      setView('transfer');
    }
  }, [pairingStatus]);

  const handleDisconnect = async () => {
    resetTransfer();
    await disconnectPairing();
    setView('home');
  };

  const handleBackToQR = () => {
    setView('home');
  };

  if (view === 'transfer' && pairingStatus === 'paired') {
    return (
      <TransferPage
        deviceName={deviceName}
        activeFile={activeFile}
        status={transferStatus}
        progress={progress}
        error={transferError}
        onDisconnect={handleDisconnect}
        onFileSelect={(file) => startTransfer(file)}
        onCancelTransfer={cancelTransfer}
        onResetTransfer={resetTransfer}
        onBackToQR={handleBackToQR}
      />
    );
  }

  return (
    <Home
      qrPayload={session?.qr_payload}
      status={pairingStatus}
      secondsLeft={secondsLeft}
      deviceName={deviceName}
      onRefresh={refreshSession}
      onGoToTransfer={() => setView('transfer')}
    />
  );
};

export default App;
