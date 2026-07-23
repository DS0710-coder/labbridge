import re

with open('/home/dev7shah/Desktop/projects/labbridge/worker/src/session.ts', 'r') as f:
    content = f.read()

# BUG-06: webSocketClose deletes all storage unconditionally.
# We shouldn't delete storage if one device disconnects briefly, but maybe we should keep it for the session TTL?
# Let's change deleteAll to just do nothing on websocket close, since alarm will clean it up anyway.
content = content.replace(
    "    await this.ctx.storage.deleteAll();\n  }\n\n  async webSocketError",
    "  }\n\n  async webSocketError"
)
content = content.replace(
    "    } catch {\n        // Already closed — ignore\n      }\n    }\n    await this.ctx.storage.deleteAll();\n  }",
    "    } catch {\n        // Already closed — ignore\n      }\n    }\n  }"
)

# BUG-07: Alarm fires during active transfer.
# Extend alarm on every message
content = content.replace(
    "  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {",
    "  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {\n    // Reset TTL\n    await this.ctx.storage.setAlarm(Date.now() + 5 * 60 * 1000);"
)

# BUG-15: Shortcut chunk keys never cleaned up.
# The alarm() deletes all storage, so it is eventually cleaned up when the session dies.
# However, if they transfer many files, they might hit the 128MB limit before session dies.
# We should clean up chunks older than a few minutes, or just clean up on `transfer_init`.
# Let's clean up all keys starting with `chunk_` on `transfer_init`.
transfer_init_fix = """
      if (parsed.type === "transfer_init") {
        // Clear all buffered chunks from any previous transfer
        const keys = await this.ctx.storage.list({ prefix: "chunk_" });
        for (const key of keys.keys()) {
          await this.ctx.storage.delete(key);
        }
"""
content = content.replace(
    "      if (parsed.type === \"transfer_init\") {",
    transfer_init_fix.strip()
)

# BUG-22: bytes_transferred reset on transfer_init
# It reset to 0 but `cumulative_transferred` gets updated, so it's correct actually!
# Let's verify line 385: `await this.ctx.storage.put("bytes_transferred", 0);`
# Actually it resets to 0 when transfer finishes. On `transfer_init`, wait, line 370.

with open('/home/dev7shah/Desktop/projects/labbridge/worker/src/session.ts', 'w') as f:
    f.write(content)
