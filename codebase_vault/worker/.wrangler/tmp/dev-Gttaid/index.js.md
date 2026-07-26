# index.js

## Architecture Metrics
- **Path:** `worker/.wrangler/tmp/dev-Gttaid/index.js`
- **Extension:** `.js`
- **Size:** 150007 bytes
- **Centrality Score:** 0.0001
- **In-Degree (Imported By):** 0
- **Out-Degree (Imports):** 0

## Explanation
*No explanation provided in source code.*

## Structural Outline
- `stripCfConnectingIPHeader`
- `generateSessionId`
- `getOtherSocket`
- `isValidSessionMessage`
- `deriveAndDecrypt`
- `checkRateLimit`
- `corsResponse`
- `reduceError`
- `__facade_register__`
- `__facade_invokeChain__`
- `__facade_invoke__`
- `wrapExportedHandler`
- `wrapWorkerEntrypoint`

## Imports (Dependencies)
*No internal imports*

## Imported By (Dependents)
*Not imported by any file*

## Source Code Snippet
```js
var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-i5N6x6/strip-cf-connecting-ip-header.js
function stripCfConnectingIPHeader(input, init) {
  const request = new Request(input, init);
  request.headers.delete("CF-Connecting-IP");
  return request;
}
__name(stripCfConnectingIPHeader, "stripCfConnectingIPHeader");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    return Reflect.apply(target, thisArg, [
      stripCfConnectingIPHeader.apply(null, argArray)
    ]);
  }
});

// src/relay.ts
function generateSessionId() {
...
```