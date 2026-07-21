import { DurableObject } from "cloudflare:workers";
import { getOtherSocket, isValidSessionMessage } from "./relay";

interface Env {
  SESSIONS: DurableObjectNamespace;
}

interface SocketAttachment {
  role: "pc" | "phone";
}

interface PendingFile {
  filename: string;
  mimeType: string;
  totalChunks: number;
  size: number;
  receivedChunks: number;
  shortcutMode: boolean;
}

async function deriveAndDecrypt(sessionId: string, encryptedBuffer: ArrayBuffer): Promise<ArrayBuffer> {
  const enc = new TextEncoder();
  const baseKey = await crypto.subtle.importKey(
    "raw", enc.encode(sessionId), { name: "HKDF" }, false, ["deriveKey"]
  );
  const key = await crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: enc.encode("labbridge-v2"),
      info: enc.encode("file-transfer")
    },
    baseKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["decrypt"]
  );
  const combined = new Uint8Array(encryptedBuffer);
  if (combined.byteLength < 12) {
    throw new Error("Encrypted buffer too short");
  }
  const iv = combined.slice(0, 12);
  const ciphertext = combined.slice(12);
  return await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    ciphertext
  );
}

const SESSION_TTL_MS = 2 * 60 * 1000; // 2 minutes (120 seconds)
const MAX_SESSION_LIFETIME_MS = 60 * 60 * 1000; // 1 hour hard maximum limit
const MAX_FILE_SIZE_BYTES = 500 * 1024 * 1024; // 500MB max limit per transfer

/**
 * A single LabBridge relay session.
 *
 * Uses the WebSocket Hibernation API so the DO can sleep between
 * messages and only wake when data arrives or the alarm fires.
 */
export class Session extends DurableObject {
  private async extendAlarm(durationMs = 4 * 60 * 1000): Promise<void> {
    const maxExpiresAt = (await this.ctx.storage.get<number>("max_expires_at")) ?? (Date.now() + MAX_SESSION_LIFETIME_MS);
    const nextAlarm = Math.min(Date.now() + durationMs, maxExpiresAt);
    await this.ctx.storage.setAlarm(nextAlarm);
  }

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

      const now = Date.now();
      const expiryMs = now + SESSION_TTL_MS;
      const maxExpiryMs = now + MAX_SESSION_LIFETIME_MS;
      await this.ctx.storage.put("session_id", sessionId);
      await this.ctx.storage.put("max_expires_at", maxExpiryMs);
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
    // ── GET /poll  (iPhone Shortcut polls for pending file) ───────────────
    if (path === "/poll") {
      const pending = await this.ctx.storage.get<PendingFile>("pending_file");
      if (!pending) {
        return Response.json({ status: "waiting" });
      }
      if (pending.receivedChunks < pending.totalChunks) {
        return Response.json({
          status: "receiving",
          received_chunks: pending.receivedChunks,
          total_chunks: pending.totalChunks,
        });
      }
      return Response.json({
        status: "file_ready",
        filename: pending.filename,
        size: pending.size,
        chunk_count: pending.totalChunks,
        mime_type: pending.mimeType,
      });
    }

    // ── GET /chunk/:index  (iPhone downloads one encrypted or decrypted chunk) ──
    const chunkPathMatch = path.match(/^\/chunk\/(\d+)$/);
    if (chunkPathMatch) {
      const chunkIndex = parseInt(chunkPathMatch[1], 10);
      const chunkKey = `chunk_${chunkIndex}`;
      const chunkData = await this.ctx.storage.get<ArrayBuffer>(chunkKey);
      if (!chunkData) {
        return new Response("Chunk not found", { status: 404 });
      }
      if (url.searchParams.get("decrypt") === "1" || url.searchParams.get("decrypt") === "true") {
        const sessionId = url.searchParams.get("id") ?? (await this.ctx.storage.get<string>("session_id")) ?? "unknown";
        try {
          const plaintext = await deriveAndDecrypt(sessionId, chunkData);
          return new Response(plaintext, {
            status: 200,
            headers: { "Content-Type": "application/octet-stream" },
          });
        } catch (err: any) {
          return new Response(`Decryption failed: ${err?.message ?? "unknown error"}`, { status: 500 });
        }
      }
      return new Response(chunkData, {
        status: 200,
        headers: { "Content-Type": "application/octet-stream" },
      });
    }

    // ── POST /phone_ack  (iPhone confirms all chunks received) ────────────
    if (path === "/phone_ack" && request.method === "POST") {
      const pending = await this.ctx.storage.get<PendingFile>("pending_file");
      if (pending) {
        const keysToDelete: string[] = ["pending_file"];
        for (let i = 0; i < pending.totalChunks; i++) {
          keysToDelete.push(`chunk_${i}`);
        }
        await this.ctx.storage.delete(keysToDelete);
      }

      const sockets = this.ctx.getWebSockets();
      for (const ws of sockets) {
        const att = ws.deserializeAttachment() as SocketAttachment | null;
        if (att?.role === "pc") {
          ws.send(JSON.stringify({ type: "shortcut_ack", message: "File received by iPhone" }));
        }
      }

      return Response.json({ status: "ok" });
    }

    // ── POST /phone_connect  (iPhone Shortcut first connect after QR scan) ──
    if (path === "/phone_connect" && request.method === "POST") {
      const sockets = this.ctx.getWebSockets();
      for (const ws of sockets) {
        const att = ws.deserializeAttachment() as SocketAttachment | null;
        if (att?.role === "pc") {
          ws.send(JSON.stringify({ type: "paired", device: "iPhone Shortcut", shortcut_mode: true }));
        }
      }
      const folders = (await this.ctx.storage.get<unknown[]>("folders")) ?? [];
      return Response.json({ status: "ok", folders });
    }

    // ── POST /decrypt  (Option A helper for iOS Shortcut) ────────────────
    if (path === "/decrypt" && request.method === "POST") {
      const sessionId = url.searchParams.get("id") ?? (await this.ctx.storage.get<string>("session_id")) ?? "unknown";
      const encryptedData = await request.arrayBuffer();
      try {
        const plaintext = await deriveAndDecrypt(sessionId, encryptedData);
        return new Response(plaintext, {
          status: 200,
          headers: { "Content-Type": "application/octet-stream" },
        });
      } catch (err: any) {
        return new Response(`Decryption failed: ${err?.message ?? "unknown error"}`, { status: 500 });
      }
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

    // If both PC and phone are now paired, reset/extend the session alarm to 240 seconds (4 minutes)
    const hasPc =
      role === "pc" ||
      existing.some((ws) => (ws.deserializeAttachment() as SocketAttachment | null)?.role === "pc");
    const hasPhone =
      role === "phone" ||
      existing.some((ws) => (ws.deserializeAttachment() as SocketAttachment | null)?.role === "phone");

    if (hasPc && hasPhone) {
      await this.extendAlarm(4 * 60 * 1000);
    }

    return new Response(null, { status: 101, webSocket: client });
  }

  /* ------------------------------------------------------------------ */
  /*  Hibernation API callbacks                                          */
  /* ------------------------------------------------------------------ */

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const sockets = this.ctx.getWebSockets();
    const other = getOtherSocket(sockets, ws);

      // Check if sender is PC and peer is not a WebSocket phone (i.e. iOS Shortcut polling mode)
      const senderAtt = ws.deserializeAttachment() as SocketAttachment | null;
      const isFromPc = senderAtt?.role === "pc";

      if (message instanceof ArrayBuffer) {
        const maxExpiresAt = (await this.ctx.storage.get<number>("max_expires_at")) ?? (Date.now() + MAX_SESSION_LIFETIME_MS);
        if (Date.now() >= maxExpiresAt) {
          ws.close(1000, "Session expired (max lifetime reached)");
          other?.close(1000, "Session expired (max lifetime reached)");
          return;
        }
        let bytesTransferred = (await this.ctx.storage.get<number>("bytes_transferred")) ?? 0;
        bytesTransferred += message.byteLength;
        if (bytesTransferred > MAX_FILE_SIZE_BYTES) {
          ws.close(1008, "Transfer size exceeds 500MB limit");
          other?.close(1008, "Transfer size exceeds 500MB limit");
          return;
        }
        await this.ctx.storage.put("bytes_transferred", bytesTransferred);

        // Check if we are in shortcut buffering mode (ONLY when PC sends chunks to iOS Shortcut)
        const pending = await this.ctx.storage.get<PendingFile>("pending_file");
        if (isFromPc && pending?.shortcutMode) {
          // Buffer this chunk in storage for the Shortcut to fetch
          const chunkIndex = pending.receivedChunks;
          await this.ctx.storage.put(`chunk_${chunkIndex}`, message);
          pending.receivedChunks++;
          await this.ctx.storage.put("pending_file", pending);

          // ACK each chunk back to PC so it keeps sending
          ws.send(JSON.stringify({ type: "ack", chunk_index: chunkIndex }));

          await this.extendAlarm(4 * 60 * 1000);
          return;
        }

        if (!other) {
          return;
        }

        // Normal relay mode — forward to other peer
        await this.extendAlarm(4 * 60 * 1000);
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

        if (parsed.type === "transfer_init") {
          const record = parsed as Record<string, unknown>;
          if (
            typeof record.size !== "number" ||
            typeof record.total_chunks !== "number" ||
            record.size < 0 ||
            record.total_chunks < 0
          ) {
            ws.send(JSON.stringify({ type: "error", message: "Invalid transfer size or chunk count" }));
            return;
          }
          if (record.size > MAX_FILE_SIZE_BYTES || record.total_chunks > Math.ceil(MAX_FILE_SIZE_BYTES / (512 * 1024))) {
            ws.close(1008, "Transfer size exceeds 500MB limit");
            other?.close(1008, "Transfer size exceeds 500MB limit");
            return;
          }

          // Check if PC is sending to an iOS Shortcut (no WebSocket phone connected)
          const phoneSocket = sockets.find(s => {
            const att = s.deserializeAttachment() as SocketAttachment | null;
            return att?.role === "phone" && s !== ws;
          });

          const shortcutMode = isFromPc && !phoneSocket;

          if (shortcutMode) {
            // Store transfer metadata — chunks will be stored as they arrive
            const pendingFile: PendingFile = {
              filename: String(record.filename ?? "file"),
              mimeType: String(record.mime_type ?? "application/octet-stream"),
              totalChunks: record.total_chunks as number,
              size: record.size as number,
              receivedChunks: 0,
              shortcutMode: true,
            };
            await this.ctx.storage.put("pending_file", pendingFile);
            await this.ctx.storage.put("bytes_transferred", 0);
            // Tell PC to start sending — shortcut will poll for completion
            ws.send(JSON.stringify({ type: "ready" }));
          } else {
            if (!other) {
              ws.send(JSON.stringify({ type: "error", message: "No peer connected" }));
              return;
            }
            // Normal WebSocket relay path — forward to peer
            const cumulative = ((await this.ctx.storage.get<number>("cumulative_transferred")) ?? 0) + (record.size as number);
            if (cumulative > MAX_FILE_SIZE_BYTES * 4) {
              ws.close(1008, "Session cumulative transfer limit exceeded");
              other.close(1008, "Session cumulative transfer limit exceeded");
              return;
            }
            await this.ctx.storage.put("cumulative_transferred", cumulative);
            await this.ctx.storage.put("bytes_transferred", 0);
            other.send(message);
          }
          return;
      }

      if (parsed.type === "folders") {
        const record = parsed as Record<string, unknown>;
        if (Array.isArray(record.folders)) {
          await this.ctx.storage.put("folders", record.folders);
        }
      }

      if (!other) {
        ws.send(JSON.stringify({ type: "error", message: "No peer connected" }));
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
    await this.ctx.storage.deleteAll();
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
    await this.ctx.storage.deleteAll();
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
