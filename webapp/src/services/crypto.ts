const SALT = new TextEncoder().encode('LabBridge-Transfer-Salt-v1');
const INFO = new TextEncoder().encode('LabBridge-AES-Key');

export async function deriveKeyFromPairingToken(pairingToken: string): Promise<CryptoKey> {
  const tokenBytes = new TextEncoder().encode(pairingToken);

  const baseKey = await window.crypto.subtle.importKey(
    'raw',
    tokenBytes,
    { name: 'HKDF' },
    false,
    ['deriveKey']
  );

  const derivedKey = await window.crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: SALT,
      info: INFO,
    },
    baseKey,
    {
      name: 'AES-GCM',
      length: 256,
    },
    false,
    ['encrypt', 'decrypt']
  );

  return derivedKey;
}

export async function encryptChunk(
  key: CryptoKey,
  chunkBuffer: ArrayBuffer
): Promise<string> {
  // Generate random 12-byte IV for each chunk
  const iv = window.crypto.getRandomValues(new Uint8Array(12));

  const encryptedBuffer = await window.crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv: iv,
    },
    key,
    chunkBuffer
  );

  const encryptedBytes = new Uint8Array(encryptedBuffer);
  const combined = new Uint8Array(iv.length + encryptedBytes.length);
  combined.set(iv, 0);
  combined.set(encryptedBytes, iv.length);

  return bufferToBase64(combined);
}

function bufferToBase64(bytes: Uint8Array): string {
  let binary = '';
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
}
