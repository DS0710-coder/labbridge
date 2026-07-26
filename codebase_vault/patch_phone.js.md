# patch_phone.js

## Architecture Metrics
- **Path:** `patch_phone.js`
- **Extension:** `.js`
- **Size:** 6031 bytes
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
const fs = require('fs');

let html = fs.readFileSync('webapp/phone.html', 'utf8');

// Replace CSS
html = html.replace(/#chat-modal \{[\s\S]*?header \{/m, 
`#chat-modal {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.85);
      backdrop-filter: blur(6px);
      z-index: 99999;
      align-items: center;
      justify-content: center;
      padding: 0;
    }
    .chat-modal-box {
      background: var(--surface);
      border: none;
...
```