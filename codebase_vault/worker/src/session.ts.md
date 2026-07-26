# session.ts

## Architecture Metrics
- **Path:** `worker/src/session.ts`
- **Extension:** `.ts`
- **Size:** 19479 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 1
- **Out-Degree (Imports):** 1

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `Session`
- `deriveAndDecrypt`

## Imports (Dependencies)
- [[worker/src/relay.ts.md|worker/src/relay.ts]]

## Imported By (Dependents)
- [[worker/src/index.ts.md|worker/src/index.ts]]

## Source Code Snippet
```ts
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

...
```