# checked-fetch.js

## Architecture Metrics
- **Path:** `worker/.wrangler/tmp/bundle-ocUGHR/checked-fetch.js`
- **Extension:** `.js`
- **Size:** 833 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `checkURL`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```js
const urls = new Set();

function checkURL(request, init) {
	const url =
		request instanceof URL
			? request
			: new URL(
					(typeof request === "string"
						? new Request(request, init)
						: request
					).url
				);
	if (url.port && url.port !== "443" && url.protocol === "https:") {
		if (!urls.has(url.toString())) {
			urls.add(url.toString());
			console.warn(
				`WARNING: known issue with \`fetch()\` requests to custom HTTPS ports in published Workers:\n` +
					` - ${url.toString()} - the custom port will be ignored when the Worker is published using the \`wrangler deploy\` command.\n`
			);
		}
...
```