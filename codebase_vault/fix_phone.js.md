# fix_phone.js

## Architecture Metrics
- **Path:** `fix_phone.js`
- **Extension:** `.js`
- **Size:** 4108 bytes
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

// Fix 1: Remove duplicate CSS blocks
html = html.replace(/    \.chat-modal-messages \{\n      flex: 1;\n      padding: 16px;\n      overflow-y: auto;\n      display: flex;\n      flex-direction: column;\n      gap: 12px;\n      background: #09090B;\n      -webkit-overflow-scrolling: touch;\n    \}\n    \.chat-modal-footer \{\n      padding: 12px;\n      padding-bottom: max\(12px, env\(safe-area-inset-bottom\)\);\n      border-top: 1px solid var\(--border\);\n      background: var\(--surface-2\);\n      display: flex;\n      gap: 10px;\n      align-items: center;\n      width: 100%;\n      box-sizing: border-box;\n    \}\n/, '');

html = html.replace('    header {', '    .chat-modal-box header {');

// Fix 2: Safari iOS tail clipping fix
html = html.replace(/z-index: -1;\n    \}/, 'z-index: 0;\n    }');
html = html.replace(/margin-left: 6px;\n    \}/, 'margin-left: 6px;\n      overflow: visible;\n    }');
html = html.replace(/justify-content: flex-start;\n    \}/, 'justify-content: flex-start;\n      overflow: visible;\n    }');

// Fix 3: chat-empty-state innerHTML bug
const newClearChat = `function clearChatMessages() {
      unreadChatCount = 0;
      updateChatBadges();
      closeChatModal();
      const list = document.getElementById('chat-modal-messages');
...
```