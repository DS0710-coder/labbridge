# middleware-insertion-facade.js

## Architecture Metrics
- **Path:** `worker/.wrangler/tmp/bundle-i5N6x6/middleware-insertion-facade.js`
- **Extension:** `.js`
- **Size:** 668 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
*No major classes or functions detected.*

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```js
				import worker, * as OTHER_EXPORTS from "/home/dev7shah/Desktop/projects/cueflex/worker/src/index.ts";
				import * as __MIDDLEWARE_0__ from "/home/dev7shah/Desktop/projects/cueflex/worker/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts";
import * as __MIDDLEWARE_1__ from "/home/dev7shah/Desktop/projects/cueflex/worker/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts";

				export * from "/home/dev7shah/Desktop/projects/cueflex/worker/src/index.ts";

				export const __INTERNAL_WRANGLER_MIDDLEWARE__ = [
					
					__MIDDLEWARE_0__.default,__MIDDLEWARE_1__.default
				]
				export default worker;
```