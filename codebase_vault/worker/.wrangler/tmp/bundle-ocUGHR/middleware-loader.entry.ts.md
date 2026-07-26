# middleware-loader.entry.ts

## Architecture Metrics
- **Path:** `worker/.wrangler/tmp/bundle-ocUGHR/middleware-loader.entry.ts`
- **Extension:** `.ts`
- **Size:** 4176 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `__Facade_ScheduledController__`
- `wrapExportedHandler`
- `wrapWorkerEntrypoint`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```ts
// This loads all middlewares exposed on the middleware object and then starts
// the invocation chain. The big idea is that we can add these to the middleware
// export dynamically through wrangler, or we can potentially let users directly
// add them as a sort of "plugin" system.

import ENTRY, { __INTERNAL_WRANGLER_MIDDLEWARE__ } from "/home/dev7shah/Desktop/projects/cueflex/worker/.wrangler/tmp/bundle-ocUGHR/middleware-insertion-facade.js";
import { __facade_invoke__, __facade_register__, Dispatcher } from "/home/dev7shah/Desktop/projects/cueflex/worker/node_modules/wrangler/templates/middleware/common.ts";
import type { WorkerEntrypointConstructor } from "/home/dev7shah/Desktop/projects/cueflex/worker/.wrangler/tmp/bundle-ocUGHR/middleware-insertion-facade.js";

// Preserve all the exports from the worker
export * from "/home/dev7shah/Desktop/projects/cueflex/worker/.wrangler/tmp/bundle-ocUGHR/middleware-insertion-facade.js";

class __Facade_ScheduledController__ implements ScheduledController {
	readonly #noRetry: ScheduledController["noRetry"];

	constructor(
		readonly scheduledTime: number,
		readonly cron: string,
		noRetry: ScheduledController["noRetry"]
	) {
...
```