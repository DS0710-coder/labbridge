# strip-cf-connecting-ip-header.js

## Architecture Metrics
- **Path:** `worker/.wrangler/tmp/bundle-ocUGHR/strip-cf-connecting-ip-header.js`
- **Extension:** `.js`
- **Size:** 351 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `stripCfConnectingIPHeader`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```js
function stripCfConnectingIPHeader(input, init) {
	const request = new Request(input, init);
	request.headers.delete("CF-Connecting-IP");
	return request;
}

globalThis.fetch = new Proxy(globalThis.fetch, {
	apply(target, thisArg, argArray) {
		return Reflect.apply(target, thisArg, [
			stripCfConnectingIPHeader.apply(null, argArray),
		]);
	},
});
```