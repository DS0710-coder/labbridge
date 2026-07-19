export interface QRPayload {
  session_id: string;
  pairing_token: string;
  expiry: number;
}

export interface PairingCreateResponse {
  session_id: string;
  qr_payload: QRPayload;
  expires_at: number;
}

export interface PairingStatusResponse {
  paired: boolean;
  user_id?: string;
  device_name?: string;
}

export interface TransferInitRequest {
  session_id: string;
  filename: string;
  size: number;
  total_chunks: number;
  mime_type: string;
}

export interface TransferStatusResponse {
  transfer_id: string;
  filename: string;
  size: number;
  total_chunks: number;
  received_chunks: number[];
  status: 'in_progress' | 'completed' | 'cancelled' | 'failed';
}

const API_BASE = '/api';

export async function createPairingSession(): Promise<PairingCreateResponse> {
  const res = await fetch(`${API_BASE}/pairing/create`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  });
  if (!res.ok) throw new Error('Failed to create pairing session');
  return res.json();
}

export async function getPairingStatus(sessionId: string): Promise<PairingStatusResponse> {
  const res = await fetch(`${API_BASE}/pairing/${sessionId}`);
  if (!res.ok) throw new Error('Failed to fetch pairing status');
  return res.json();
}

export async function deletePairingSession(sessionId: string): Promise<void> {
  await fetch(`${API_BASE}/pairing/${sessionId}`, { method: 'DELETE' });
}

export async function initTransfer(request: TransferInitRequest): Promise<{ transfer_id: string }> {
  const res = await fetch(`${API_BASE}/transfer/init`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(request),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Failed to init transfer' }));
    throw new Error(err.detail || 'Failed to init transfer');
  }
  return res.json();
}

export async function uploadChunk(
  transferId: string,
  chunkIndex: number,
  encryptedData: string
): Promise<void> {
  const res = await fetch(`${API_BASE}/transfer/${transferId}/chunk`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chunk_index: chunkIndex, encrypted_data: encryptedData }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: `Failed to upload chunk ${chunkIndex}` }));
    throw new Error(err.detail || `Failed to upload chunk ${chunkIndex}`);
  }
}

export async function getTransferStatus(transferId: string): Promise<TransferStatusResponse> {
  const res = await fetch(`${API_BASE}/transfer/${transferId}/status`);
  if (!res.ok) throw new Error('Failed to check transfer status');
  return res.json();
}

export async function cancelTransfer(transferId: string): Promise<void> {
  await fetch(`${API_BASE}/transfer/${transferId}/cancel`, { method: 'POST' });
}
