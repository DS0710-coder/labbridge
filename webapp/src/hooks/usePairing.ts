import { useState, useEffect, useRef, useCallback } from 'react';
import {
  createPairingSession,
  deletePairingSession,
} from '../services/api';
import type { PairingCreateResponse } from '../services/api';

export type PairingStatus = 'connecting' | 'waiting' | 'paired' | 'error';

export function usePairing() {
  const [session, setSession] = useState<PairingCreateResponse | null>(null);
  const [status, setStatus] = useState<PairingStatus>('connecting');
  const [deviceName, setDeviceName] = useState<string | null>(null);
  const [secondsLeft, setSecondsLeft] = useState<number>(120);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const timerRef = useRef<number | null>(null);

  const initSession = useCallback(async () => {
    try {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }

      setStatus('connecting');
      setErrorMessage(null);

      const newSession = await createPairingSession();
      setSession(newSession);
      setSecondsLeft(120);
      setStatus('waiting');

      // Connect WebSocket for real-time pairing notification
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = `${protocol}//${window.location.host}/ws/pairing/${newSession.session_id}`;
      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.event === 'paired') {
            setStatus('paired');
            setDeviceName(data.device_name || 'Connected Device');
          } else if (data.event === 'disconnected') {
            setStatus('waiting');
            setDeviceName(null);
            initSession();
          }
        } catch (err) {
          console.error('Error parsing WebSocket message:', err);
        }
      };

      ws.onerror = () => {
        console.error('Pairing WebSocket error');
      };
    } catch (err: any) {
      console.error('Failed to init pairing session:', err);
      setStatus('error');
      setErrorMessage(err.message || 'Connection failed');
    }
  }, []);

  // Countdown and Auto-refresh every 90 seconds (when secondsLeft reaches 30)
  useEffect(() => {
    if (status !== 'waiting') return;

    timerRef.current = window.setInterval(() => {
      setSecondsLeft((prev) => {
        if (prev <= 30) {
          // Auto-refresh before expiry without user action (elapsed 90 seconds)
          initSession();
          return 120;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [status, initSession]);

  useEffect(() => {
    initSession();
    return () => {
      if (wsRef.current) wsRef.current.close();
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [initSession]);

  const disconnect = useCallback(async () => {
    if (session?.session_id) {
      try {
        await deletePairingSession(session.session_id);
      } catch (err) {
        console.error('Error deleting session on disconnect:', err);
      }
    }
    setDeviceName(null);
    initSession();
  }, [session, initSession]);

  return {
    session,
    status,
    deviceName,
    secondsLeft,
    errorMessage,
    refreshSession: initSession,
    disconnect,
  };
}
