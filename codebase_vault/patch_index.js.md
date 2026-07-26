# patch_index.js

## Architecture Metrics
- **Path:** `patch_index.js`
- **Extension:** `.js`
- **Size:** 6080 bytes
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

let html = fs.readFileSync('webapp/index.html', 'utf8');

// Replace CSS
html = html.replace(/#chat-modal \{[\s\S]*?@media \(max-width: 640px\)/m, 
`#chat-modal {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(4px);
      z-index: 99999;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    .chat-modal-box {
      background: #000000;
      width: 100%;
...
```