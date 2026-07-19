import { DurableObject } from "cloudflare:workers";
import { getOtherSocket, isValidSessionMessage } from "./relay";

interface Env {
  SESSIONS: DurableObjectNamespace;
}

interface SocketAttachment {
  role: "pc" | "phone";
}

const SESSION_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * A single LabBridge relay session.
 *
 * Uses the WebSocket Hibernation API so the DO can sleep between
 * messages and only wake when data arrives or the alarm fires.
 */
export class Session extends DurableObject {
  /* ------------------------------------------------------------------ */
  /*  HTTP / WebSocket upgrade handler                                   */
  /* ------------------------------------------------------------------ */

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // ── Create a new session ──────────────────────────────────────────
    if (path === "/session/new") {
      // Extract session_id that was set by the edge worker
      const sessionId = url.searchParams.get("id") ?? "unknown";

      const expiryMs = Date.now() + SESSION_TTL_MS;
      await this.ctx.storage.setAlarm(expiryMs);

      const expiresAt = new Date(expiryMs).toISOString();
      const qrPayload = JSON.stringify({ s: sessionId, e: expiryMs });

      return Response.json({
        session_id: sessionId,
        qr_payload: qrPayload,
        expires_at: expiresAt,
      });
    }

    // ── WebSocket upgrade for /pc or /phone ──────────────────────────
    const roleMatch = path.match(/\/(pc|phone)$/);
    if (!roleMatch) {
      return new Response("Not found", { status: 404 });
    }

    const role = roleMatch[1] as "pc" | "phone";

    // Require Upgrade header
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket upgrade", { status: 426 });
    }

    // Enforce one-PC, one-phone policy
    const existing = this.ctx.getWebSockets();
    for (const ws of existing) {
      const att = ws.deserializeAttachment() as SocketAttachment | null;
      if (att && att.role === role) {
        return new Response(`A ${role} is already connected`, { status: 409 });
      }
    }

    // Create the WebSocket pair
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];

    // Tag with role and accept via Hibernation API
    server.serializeAttachment({ role } satisfies SocketAttachment);
    this.ctx.acceptWebSocket(server);

    // Send initial messages based on role
    if (role === "pc") {
      // Check if phone is already connected
      const phoneConnected = existing.some((ws) => {
        const att = ws.deserializeAttachment() as SocketAttachment | null;
        return att?.role === "phone";
      });

      if (phoneConnected) {
        server.send(JSON.stringify({ type: "paired", device: "phone" }));
      } else {
        server.send(JSON.stringify({ type: "waiting" }));
      }
    }

    if (role === "phone") {
      // Tell the phone to send its folder structure
      server.send(JSON.stringify({ type: "folder_request" }));

      // Notify the PC that a phone has paired
      for (const ws of existing) {
        const att = ws.deserializeAttachment() as SocketAttachment | null;
        if (att?.role === "pc") {
          ws.send(JSON.stringify({ type: "paired", device: "phone" }));
        }
      }
    }

    return new Response(null, { status: 101, webSocket: client });
  }

  /* ------------------------------------------------------------------ */
  /*  Hibernation API callbacks                                          */
  /* ------------------------------------------------------------------ */

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const sockets = this.ctx.getWebSockets();
    const other = getOtherSocket(sockets, ws);

    if (!other) {
      // No peer connected yet — for text messages we can inform the sender
      if (typeof message === "string") {
        ws.send(JSON.stringify({ type: "error", message: "No peer connected" }));
      }
      return;
    }

    // Binary frames: relay as-is (encrypted file chunks)
    if (message instanceof ArrayBuffer) {
      other.send(message);
      return;
    }

    // Text frames: validate minimally, then forward
    try {
      const parsed: unknown = JSON.parse(message);
      if (!isValidSessionMessage(parsed)) {
        ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
        return;
      }
      other.send(message);
    } catch {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
    }
  }

  async webSocketClose(
    ws: WebSocket,
    code: number,
    reason: string,
    wasClean: boolean,
  ): Promise<void> {
    // Close the peer socket so both sides know the session is over
    const sockets = this.ctx.getWebSockets();
    const other = getOtherSocket(sockets, ws);
    if (other) {
      try {
        other.close(1000, "Peer disconnected");
      } catch {
        // Already closed — ignore
      }
    }
  }

  async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
    // On error, tear down both connections
    const sockets = this.ctx.getWebSockets();
    for (const s of sockets) {
      try {
        s.close(1011, "WebSocket error");
      } catch {
        // Already closed — ignore
      }
    }
  }

  /* ------------------------------------------------------------------ */
  /*  Alarm: session TTL self-destruct                                   */
  /* ------------------------------------------------------------------ */

  async alarm(): Promise<void> {
    // Close all sockets
    const sockets = this.ctx.getWebSockets();
    for (const ws of sockets) {
      try {
        ws.close(1000, "Session expired");
      } catch {
        // Already closed — ignore
      }
    }

    // Wipe storage so the DO can be garbage-collected
    await this.ctx.storage.deleteAll();
  }
}
