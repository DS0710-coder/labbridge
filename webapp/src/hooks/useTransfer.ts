import { useState, useRef, useCallback, useEffect } from 'react';
import { initTransfer, uploadChunk, cancelTransfer } from '../services/api';
import { deriveKeyFromPairingToken, encryptChunk } from '../services/crypto';
import { prepareFileChunker } from '../services/chunker';

export type TransferStatus = 'idle' | 'uploading' | 'completed' | 'error' | 'cancelled';

export interface TransferProgress {
  currentChunk: number;
  totalChunks: number;
  percentage: number;
  speedMbps: number;
}

export function useTransfer(sessionId: string | null, pairingToken: string | null) {
  const [activeFile, setActiveFile] = useState<File | null>(null);
  const [status, setStatus] = useState<TransferStatus>('idle');
  const [progress, setProgress] = useState<TransferProgress>({
    currentChunk: 0,
    totalChunks: 0,
    percentage: 0,
    speedMbps: 0,
  });
  const [error, setError] = useState<string | null>(null);
  const [transferId, setTransferId] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const cancelledRef = useRef<boolean>(false);
  const startTimeRef = useRef<number>(0);

  // Connect WebSocket when session is active
  useEffect(() => {
    if (!sessionId) return;

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/transfer/${sessionId}`;
    const ws = new WebSocket(wsUrl);
    wsRef.current = ws;

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.event === 'ack') {
          // Chunk acknowledged by phone
          const chunkIdx = data.chunk_index;
          setProgress((prev) => {
            const nextIdx = Math.max(prev.currentChunk, chunkIdx + 1);
            const pct = Math.round((nextIdx / prev.totalChunks) * 100);
            return { ...prev, currentChunk: nextIdx, percentage: pct };
          });
        } else if (data.event === 'completed') {
          setStatus('completed');
          setProgress((prev) => ({ ...prev, percentage: 100 }));
        } else if (data.event === 'cancelled') {
          setStatus('cancelled');
        }
      } catch (err) {
        console.error('Error parsing transfer WS message:', err);
      }
    };

    return () => {
      ws.close();
    };
  }, [sessionId]);

  const startTransfer = useCallback(
    async (file: File) => {
      if (!sessionId || !pairingToken) {
        setError('Not paired with any device');
        return;
      }

      if (file.size > 500 * 1024 * 1024) {
        setError('File exceeds maximum size of 500MB');
        return;
      }

      cancelledRef.current = false;
      setActiveFile(file);
      setStatus('uploading');
      setError(null);
      startTimeRef.current = performance.now();

      try {
        // 1. Prepare encryption key from pairing token
        const cryptoKey = await deriveKeyFromPairingToken(pairingToken);

        // 2. Prepare file chunker
        const chunker = prepareFileChunker(file);
        setProgress({
          currentChunk: 0,
          totalChunks: chunker.totalChunks,
          percentage: 0,
          speedMbps: 0,
        });

        // 3. Init transfer on backend
        const initRes = await initTransfer({
          session_id: sessionId,
          filename: file.name,
          size: file.size,
          total_chunks: chunker.totalChunks,
          mime_type: file.type || 'application/octet-stream',
        });
        setTransferId(initRes.transfer_id);

        let uploadedBytes = 0;

        // 4. Sequential chunk upload with AES-256-GCM encryption
        for (let i = 0; i < chunker.totalChunks; i++) {
          if (cancelledRef.current) {
            await cancelTransfer(initRes.transfer_id);
            setStatus('cancelled');
            return;
          }

          const rawBuffer = await chunker.getChunkBuffer(i);
          const encryptedBase64 = await encryptChunk(cryptoKey, rawBuffer);

          await uploadChunk(initRes.transfer_id, i, encryptedBase64);

          uploadedBytes += rawBuffer.byteLength;
          const elapsedSec = (performance.now() - startTimeRef.current) / 1000;
          const speedMbps = elapsedSec > 0 ? Number(((uploadedBytes * 8) / (elapsedSec * 1_000_000)).toFixed(2)) : 0;

          setProgress({
            currentChunk: i + 1,
            totalChunks: chunker.totalChunks,
            percentage: Math.round(((i + 1) / chunker.totalChunks) * 100),
            speedMbps,
          });
        }

        // Complete
        setStatus('completed');
      } catch (err: any) {
        if (!cancelledRef.current) {
          console.error('Transfer error:', err);
          setError(err.message || 'File transfer failed');
          setStatus('error');
        }
      }
    },
    [sessionId, pairingToken]
  );

  const cancelCurrentTransfer = useCallback(async () => {
    cancelledRef.current = true;
    if (transferId) {
      try {
        await cancelTransfer(transferId);
      } catch (err) {
        console.error('Error cancelling transfer:', err);
      }
    }
    setStatus('cancelled');
  }, [transferId]);

  const reset = useCallback(() => {
    setActiveFile(null);
    setStatus('idle');
    setError(null);
    setTransferId(null);
    setProgress({ currentChunk: 0, totalChunks: 0, percentage: 0, speedMbps: 0 });
  }, []);

  return {
    activeFile,
    status,
    progress,
    error,
    startTransfer,
    cancelTransfer: cancelCurrentTransfer,
    reset,
  };
}
