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

/** Minimal validation: the parsed JSON must be a non-null object with a `type` string. */
export function isValidSessionMessage(data: unknown): data is { type: string } {
  return (
    typeof data === "object" &&
    data !== null &&
    "type" in data &&
    typeof (data as Record<string, unknown>).type === "string"
  );
}
