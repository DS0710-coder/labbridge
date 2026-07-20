/**
 * Relay helper utilities for the LabBridge worker.
 * Pure functions — no state, no side effects.
 */

/** Generate a 12-char alphanumeric session ID from a random UUID. */
export function generateSessionId(): string {
  return crypto.randomUUID().replace(/-/g, "").substring(0, 12);
}

/**
 * Given the full set of hibernatable WebSockets on the Durable Object,
 * return the socket that is NOT `currentWs`, i.e. the other peer.
 * Returns null if no other socket exists.
 */
export function getOtherSocket(
  sockets: WebSocket[],
  currentWs: WebSocket,
): WebSocket | null {
  for (const ws of sockets) {
    if (ws !== currentWs) {
      return ws;
    }
  }
  return null;
}

const ALLOWED_MESSAGE_TYPES = new Set([
  "waiting",
  "paired",
  "folder_request",
  "folders",
  "ready",
  "transfer_init",
  "ack",
  "cancelled",
  "disconnected",
  "error",
]);

/** Minimal validation: the parsed JSON must be a non-null object with a valid `type` string. */
export function isValidSessionMessage(data: unknown): data is { type: string } {
  if (typeof data !== "object" || data === null || !("type" in data)) {
    return false;
  }
  const typeVal = (data as Record<string, unknown>).type;
  return typeof typeVal === "string" && ALLOWED_MESSAGE_TYPES.has(typeVal);
}
