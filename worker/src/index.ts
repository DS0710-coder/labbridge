/**
 * LabBridge v2 — Cloudflare Worker entry point.
 *
 * Pure relay: routes requests to Session Durable Objects,
 * stores nothing, knows nothing about users or files.
 */

import { generateSessionId } from "./relay";

// Re-export the Durable Object class so wrangler can discover it
export { Session } from "./session";

interface Env {
  SESSIONS: DurableObjectNamespace;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

const ipRequests = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string, limit: number, windowMs: number): boolean {
  const now = Date.now();
  const record = ipRequests.get(ip);
  if (!record || now > record.resetAt) {
    ipRequests.set(ip, { count: 1, resetAt: now + windowMs });
    if (ipRequests.size > 10000) {
      for (const [key, val] of ipRequests.entries()) {
        if (now > val.resetAt) ipRequests.delete(key);
      }
    }
    return true;
  }
  if (record.count >= limit) {
    return false;
  }
  record.count++;
  return true;
}

function corsResponse(body: string | null, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  for (const [k, v] of Object.entries(CORS_HEADERS)) {
    headers.set(k, v);
  }
  return new Response(body, { ...init, headers });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return corsResponse(null, { status: 204 });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const ip = request.headers.get("CF-Connecting-IP") ?? request.headers.get("X-Forwarded-For") ?? "unknown";

    // ── GET /session/new ──────────────────────────────────────────────
    if (path === "/session/new" && request.method === "GET") {
      if (!checkRateLimit(`new:${ip}`, 20, 60 * 1000)) {
        return corsResponse(JSON.stringify({ error: "Rate limit exceeded. Please try again later." }), {
          status: 429,
          headers: { "Content-Type": "application/json", "Retry-After": "60" },
        });
      }

      const sessionId = generateSessionId();
      const doId = env.SESSIONS.idFromName(sessionId);
      const stub = env.SESSIONS.get(doId);

      // Forward to the DO, passing the session ID as a query param
      const doUrl = new URL(request.url);
      doUrl.searchParams.set("id", sessionId);
      const res = await stub.fetch(doUrl.toString());
      const body = await res.text();

      return corsResponse(body, {
        status: res.status,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── GET /session/:id/pc  or  /session/:id/phone ──────────────────
    const wsMatch = path.match(/^\/session\/([a-zA-Z0-9]{12})\/(pc|phone)$/);
    if (wsMatch && request.method === "GET") {
      if (!checkRateLimit(`ws:${ip}`, 60, 60 * 1000)) {
        return corsResponse("Rate limit exceeded", { status: 429 });
      }

      const [, sessionId, role] = wsMatch;
      const doId = env.SESSIONS.idFromName(sessionId);
      const stub = env.SESSIONS.get(doId);

      // Forward the upgrade request directly to the Durable Object
      const doUrl = new URL(request.url);
      doUrl.pathname = `/${role}`;
      return stub.fetch(doUrl.toString(), request);
    }

    // ── Fallback ──────────────────────────────────────────────────────
    return corsResponse("Not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
